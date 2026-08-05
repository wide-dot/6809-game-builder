package com.widedot.m6809.gamebuilder;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;
import com.widedot.m6809.gamebuilder.spi.globals.LinkReport;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Target {
	
	private final BuildContext ctx;

	public Target(BuildContext ctx) throws Exception {
		this.ctx = ctx;
	}
	
	public void processTargetSelection(ImmutableNode root, String[] targets) throws Exception {
		log.info("Processing targets: {}", Arrays.toString(targets));
		List<ImmutableNode> nodesToProcess = new ArrayList<ImmutableNode>();
		for (ImmutableNode target : root.getChildren()) {
			if (!"target".equals(target.getNodeName())) {
				continue;
			}
			String name = (String) target.getAttributes().get("name");
			for (int i = 0; i < targets.length; i++) {
				if (targets[i].equals(name)) {
					nodesToProcess.add(target);
				}
			}
		}
		if (nodesToProcess.isEmpty()) {
			throw new Exception("None of the requested targets " + Arrays.toString(targets)
					+ " exists in the configuration file");
		}
		processTargets(nodesToProcess);
	}
    
	public void processAllTargets(ImmutableNode root) throws Exception {
		log.info("Processing all targets in configuration file.");
		List<ImmutableNode> nodesToProcess = new ArrayList<ImmutableNode>();
		for (ImmutableNode target : root.getChildren()) {
			if ("target".equals(target.getNodeName())) {
				nodesToProcess.add(target);
			}
		}
		if (nodesToProcess.isEmpty()) {
			String m = "No target found !";
			log.error(m);
			throw new Exception(m);
		}
   		processTargets(nodesToProcess);
	}
	
	private void processTargets(List<ImmutableNode> targetNodes) throws Exception {

    	for(ImmutableNode node : targetNodes)
    	{
			String targetName = (String) node.getAttributes().get("name");
			log.info("Processing target {}", targetName);

			// discovery pass : link symbol ids get baked into the link data as
			// each entry is built, and the full symbol set (all disks) is only
			// known at the end. Run the target once to collect the symbols,
			// then rerun it with ids preseeded in alphabetical order — ids
			// depend on the symbol names only, so reordering sources no longer
			// renumbers every image. An error here is left for the real pass
			// to report, with whatever symbols were seen preseeded.
			ctx.resetTarget();
			com.widedot.m6809.gamebuilder.config.PlacementScan.run(node, ctx);
			// discovery also harvests the static-link export table : baking is
			// deferred (references are marked consumed, nothing is resolved),
			// so a consumer declared before its provider cannot stop the pass
			ctx.staticLink.setDiscovery(true);
			Exception discoveryStop = null;
			try {
				runTarget(node);
			} catch (Exception e) {
				discoveryStop = e;
				log.warn("discovery pass stopped early: {}", e.getMessage());
			}
			// what AUTO will leave load-time linked was invisible to the
			// discovery emission (its baked sections skip the link data) :
			// classify the recorded candidates now, so those symbols get ids
			// and their providers' exports survive the pruning
			java.util.Set<String> predictedLinked = ctx.staticLink.predictLinkedImports();
			List<String> symbols = new ArrayList<String>(ctx.linkSymbols.ids.keySet());
			for (String name : predictedLinked) {
				if (!ctx.linkSymbols.ids.containsKey(name)) {
					symbols.add(name);
				}
			}
			java.util.Collections.sort(symbols);
			java.util.Set<String> imported = new java.util.HashSet<String>(ctx.linkSymbols.imports);
			imported.addAll(predictedLinked);
			log.info("{} link symbols discovered ({} imported), ids assigned alphabetically",
					symbols.size(), imported.size());
			log.debug("imported : {}", imported);
			com.widedot.m6809.gamebuilder.spi.globals.StaticLink.Harvest discoveredStatic =
					ctx.staticLink.snapshot();
			// what each region's content measured : size="auto" reads it back
			java.util.Map<String, Integer> measured = ctx.ramMap.contentSizes();
			java.util.Map<String, Integer> measuredPages = ctx.regions.pagesUsedSnapshot();
			// a discovery that died before the scenes leaves the measures
			// empty : the real pass would lay every size="auto" region out at
			// a full page and write a disk that loads over the monitor. Better
			// no disk than that one.
			if (discoveryStop != null && measured.isEmpty()) {
				throw new Exception("discovery pass failed before measuring the layout — "
						+ discoveryStop.getMessage(), discoveryStop);
			}

			// ids and defines are global to a target : restart them so that two
			// targets of the same game (fd, t2, ...) get identical ids, and so
			// that building "-t fd" alone or "-t sd,fd" yields the same image
			ctx.resetTarget();
			// the measures go in BEFORE the placement scan : the scan resolves
			// size="auto" too, and a scan that disagreed with the layout would
			// bake references against addresses nothing ever loads at
			ctx.regions.seedMeasured(measured);
			ctx.regions.seedMeasuredPages(measuredPages);
			com.widedot.m6809.gamebuilder.config.PlacementScan.run(node, ctx);
			ctx.linkSymbols.preseed(symbols);
			ctx.linkSymbols.preseedImports(imported);
			// the real pass bakes against the discovered offsets : declaration
			// order no longer decides whether a provider is resolvable, and a
			// symbol exported by several run-time alternatives is refused
			// deterministically instead of resolving to whichever came last
			ctx.staticLink.preseed(discoveredStatic);

			// The images are written as the target runs, but the checks that
			// close it come after — so a refused build would leave a freshly
			// timestamped disk in dist/ that boots into garbage. Anything this
			// target produced goes away with it.
			try {
				runTarget(node);
				if (ctx.linkSymbols.pruned > 0) {
					log.info("{} exports never imported, left out of the link data", ctx.linkSymbols.pruned);
				}
				// the promise made by interface="true" regions is checked against
				// what the link data actually emits, so it holds post-prune
				ctx.staticLink.checkInterfaces(ctx.linkSymbols.unitExports);
				// a file that dropped linkdata must not still be imported
				ctx.linkSymbols.checkImportsResolvable();
			} catch (Exception e) {
				discardOutputs(targetName);
				throw e;
			}
			reportLinkData(targetName);
			writeRamMap(targetName);
			writePoolMap(targetName, node);
			log.info("End of processing target {}", targetName);

    	}
	}

	/**
	 * Removes what a failed target wrote : its images, and the link report of
	 * whatever build came before, which would otherwise sit in {@code dist/}
	 * describing a build that no longer exists.
	 */
	private void discardOutputs(String targetName) {
		int removed = ctx.outputs.discard();
		try {
			java.nio.file.Path stale = linkReportPath(targetName);
			if (java.nio.file.Files.deleteIfExists(stale)) {
				removed++;
				log.info("removed {} : it described an earlier build", stale);
			}
			java.nio.file.Path staleMap = ramMapPath(targetName);
			if (java.nio.file.Files.deleteIfExists(staleMap)) {
				removed++;
				log.info("removed {} : it described an earlier build", staleMap);
			}
			java.nio.file.Path stalePool = poolMapPath(targetName);
			if (java.nio.file.Files.deleteIfExists(stalePool)) {
				removed++;
				log.info("removed {} : it described an earlier build", stalePool);
			}
		} catch (Exception e) {
			log.warn("could not remove the stale reports: {}", e.getMessage());
		}
		if (removed > 0) {
			log.error("target {} failed : {} output file(s) removed, dist holds nothing"
					+ " from this build", targetName, removed);
		}
	}

	/**
	 * Where each scene lands, and what its budgets leave over.
	 *
	 * Destinations are placed by hand ; this is the measurement they are placed
	 * against. One map per scene — a composition is the unit that gets
	 * optimised — with the whole declared layout in each, since a budget is
	 * reserved whether or not that scene fills it.
	 */
	private void writeRamMap(String targetName) {
		if (ctx.ramMap.isEmpty()) {
			return;
		}
		java.nio.file.Path path = ramMapPath(targetName);
		try {
			java.nio.file.Files.createDirectories(path.getParent());
			java.nio.file.Files.writeString(path,
					com.widedot.m6809.gamebuilder.plugin.scene.RamMapReport.render(
							targetName, ctx.ramMap, ctx.regions));
			log.info("RAM occupancy map written to {}", path);
		} catch (Exception e) {
			log.warn("could not write the RAM occupancy map: {}", e.getMessage());
		}
	}

	/**
	 * The other budget a scene is placed against : what the loader's memory
	 * pool has to hold to link it. The RAM map says where a scene lands, this
	 * says what linking it costs — and an overflow of this one is the failure
	 * that shows nothing at all on screen.
	 */
	private void writePoolMap(String targetName, ImmutableNode node) {
		if (ctx.ramMap.isEmpty()) {
			return;
		}
		java.nio.file.Path path = poolMapPath(targetName);
		try {
			java.nio.file.Files.createDirectories(path.getParent());
			java.nio.file.Files.writeString(path,
					com.widedot.m6809.gamebuilder.plugin.scene.PoolMapReport.render(
							targetName, ctx.ramMap, ctx.linkReport, declaredPoolSize(node)));
			log.info("link data pool map written to {}", path);
		} catch (Exception e) {
			log.warn("could not write the link data pool map: {}", e.getMessage());
		}
	}

	/**
	 * {@code loader.DEFAULT_DYNAMIC_MEMORY_SIZE} as the target declares it, or
	 * -1 when it does not : the pool map is then drawn without a budget rather
	 * than not drawn at all.
	 *
	 * Read from the configuration tree rather than from {@code ctx.defines}.
	 * A {@code <define>} is scoped to the container it sits in — the child
	 * context keeps it and only republishes what went through
	 * {@code newValues} — so by the time the target closes, the value is no
	 * longer in scope. The declaration is, and this report is observational.
	 */
	private int declaredPoolSize(ImmutableNode node) {
		String value = findDefine(node, "loader.DEFAULT_DYNAMIC_MEMORY_SIZE");
		if (value == null) {
			return -1;
		}
		try {
			String text = value.trim();
			if (text.startsWith("$")) {
				return Integer.parseInt(text.substring(1), 16);
			}
			if (text.startsWith("0x") || text.startsWith("0X")) {
				return Integer.parseInt(text.substring(2), 16);
			}
			return Integer.parseInt(text);
		} catch (NumberFormatException e) {
			// the loader's default is an expression, not a literal : no budget
			// to draw against, but the per-scene totals still stand
			return -1;
		}
	}

	/** first {@code <define symbol="...">} at or under this node, depth first */
	private String findDefine(ImmutableNode node, String symbol) {
		if ("define".equals(node.getNodeName())
				&& symbol.equals(node.getAttributes().get("symbol"))) {
			Object value = node.getAttributes().get("value");
			return value == null ? "1" : value.toString();
		}
		for (ImmutableNode child : node.getChildren()) {
			String found = findDefine(child, symbol);
			if (found != null) {
				return found;
			}
		}
		return null;
	}

	private java.nio.file.Path poolMapPath(String targetName) {
		return java.nio.file.Paths.get(
				ctx.path + java.io.File.separator + ctx.settings.get("dist.dir"),
				"pool-map-" + targetName + ".txt");
	}

	private java.nio.file.Path ramMapPath(String targetName) {
		return java.nio.file.Paths.get(
				ctx.path + java.io.File.separator + ctx.settings.get("dist.dir"),
				"ram-map-" + targetName + ".txt");
	}

	private java.nio.file.Path linkReportPath(String targetName) {
		return java.nio.file.Paths.get(
				ctx.path + java.io.File.separator + ctx.settings.get("dist.dir"),
				"link-report-" + targetName + ".csv");
	}

	/**
	 * Consolidated view of what the target's link data costs, so the
	 * {@code .static} policy can be arbitrated on numbers rather than on a
	 * hunch — see {@code docs/lang/en/symbols.md}, "The policy".
	 *
	 * The loader keeps a file's link block in its memory pool for as long as
	 * the file stays indexed, so the total is what the pool must hold if every
	 * entry is indexed at once. A large block with nothing baked is a unit the
	 * policy has not reached.
	 */
	private void reportLinkData(String targetName) {
		List<LinkReport.Entry> costly = ctx.linkReport.costly();
		int total = ctx.linkReport.totalBytes();

		if (costly.isEmpty()) {
			log.info("link data: none — every file of target {} is fully baked or unlinked",
					targetName);
		} else {
			log.info("link data: {} direntries, {} bytes (pool cost while indexed), {} references baked",
					costly.size(), total, ctx.linkReport.totalBaked());
			log.info("  bytes  intern  x8  x16  page  expA  expR   baked  file");
			for (LinkReport.Entry e : costly) {
				log.info(String.format("%7d %7d %3d %4d %5d %5d %5d %7d  %s",
						e.bytes, e.intern, e.extern8, e.extern16, e.externPage,
						e.exportAbs, e.exportRel, e.baked, e.name));
			}
		}

		// the same table on disk, one row per file — including the entries
		// that cost nothing, so a sweep can be diffed between two builds
		java.nio.file.Path csv = linkReportPath(targetName);
		StringBuilder sb = new StringBuilder(
				"file,bytes,intern,extern8,extern16,externPage,exportAbs,exportRel,references,baked,linkdata\n");
		for (LinkReport.Entry e : ctx.linkReport.entries()) {
			sb.append(e.name).append(',')
			  .append(e.bytes).append(',')
			  .append(e.intern).append(',')
			  .append(e.extern8).append(',')
			  .append(e.extern16).append(',')
			  .append(e.externPage).append(',')
			  .append(e.exportAbs).append(',')
			  .append(e.exportRel).append(',')
			  .append(e.references()).append(',')
			  .append(e.baked).append(',')
			  .append(e.linkdata).append('\n');
		}
		try {
			java.nio.file.Files.createDirectories(csv.getParent());
			java.nio.file.Files.write(csv, sb.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));
			log.info("link report written to {}", csv);
		} catch (Exception e) {
			// a report is never worth failing a build that otherwise succeeded
			log.warn("could not write the link report to {}: {}", csv, e.getMessage());
		}
	}

	private void runTarget(ImmutableNode node) throws Exception {
		for (ImmutableNode child : node.getChildren()) {
			String plugin = child.getNodeName();

			DefaultPluginInterface defaultHandler = Handlers.getDefault(plugin);
			ObjectPluginInterface objectHandler = Handlers.getObject(plugin);

			if (defaultHandler == null && objectHandler == null) {
				throw new Exception("Element <" + plugin + "> is not valid here");
			}

			if (defaultHandler != null) {
				log.debug("Running handler: {}", plugin);
				defaultHandler.run(child, ctx);
			}

			if (objectHandler != null) {
				log.debug("Running handler: {}", plugin);
				objectHandler.getObject(child, ctx);
			}
		}
	}
}
