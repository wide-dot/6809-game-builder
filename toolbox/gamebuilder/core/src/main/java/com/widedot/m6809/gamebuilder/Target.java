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
	
	/** what one discovery pass learned : measures, symbol ids, export table */
	private static class Discovery {
		java.util.Map<String, Integer> measured;
		java.util.Map<String, Integer> fileSizes;
		List<String> symbols;
		java.util.Set<String> imported;
		com.widedot.m6809.gamebuilder.spi.globals.StaticLink.Harvest harvest;
		/** what stopped it, or null : an error is left for the real pass to report */
		Exception stop;
	}

	/**
	 * Run the target for what it teaches, not for what it writes : binaries
	 * are thrown away, baking is deferred (references are marked consumed,
	 * nothing is resolved), so a consumer declared before its provider cannot
	 * stop the pass.
	 *
	 * @param measured measures from an earlier pass, or null on the first one
	 */
	private Discovery discoveryPass(ImmutableNode node, java.util.Map<String, Integer> measured,
			java.util.Map<String, Integer> fileSizes) throws Exception {

		Discovery out = new Discovery();
		ctx.resetTarget();
		if (measured != null) {
			ctx.regions.seedMeasured(measured);
			ctx.regions.seedFileSizes(fileSizes);
		}
		com.widedot.m6809.gamebuilder.config.PlacementScan.run(node, ctx);
		ctx.staticLink.setDiscovery(true);
		try {
			runTarget(node);
		} catch (Exception e) {
			out.stop = e;
			log.warn("discovery pass stopped early: {}", e.getMessage());
		}
		// what AUTO will leave load-time linked was invisible to the discovery
		// emission (its baked sections skip the link data) : classify the
		// recorded candidates now, so those symbols get ids and their
		// providers' exports survive the pruning
		java.util.Set<String> predictedLinked = ctx.staticLink.predictLinkedImports();
		out.symbols = new ArrayList<String>(ctx.linkSymbols.ids.keySet());
		for (String name : predictedLinked) {
			if (!ctx.linkSymbols.ids.containsKey(name)) {
				out.symbols.add(name);
			}
		}
		java.util.Collections.sort(out.symbols);
		out.imported = new java.util.HashSet<String>(ctx.linkSymbols.imports);
		out.imported.addAll(predictedLinked);
		out.harvest = ctx.staticLink.snapshot();
		out.measured = ctx.ramMap.contentSizes();
		out.fileSizes = ctx.ramMap.fileSizes();
		return out;
	}

	private void processTargets(List<ImmutableNode> targetNodes) throws Exception {

    	for(ImmutableNode node : targetNodes)
    	{
			String targetName = (String) node.getAttributes().get("name");
			log.info("Processing target {}", targetName);

			// Two discovery passes, then the real one.
			//
			// A discovery pass exists because ids and exports are only fully
			// known at the end : it runs the whole target, throws the binaries
			// away and keeps what it learned. But it also MEASURES the layout,
			// and a layout with measured sizes is not the layout it was built
			// against — while measuring, a size the author left to the builder
			// takes a whole page, so regions stacked on one page sit at $4000,
			// $8000... The exports harvested there carry those addresses.
			//
			// It went unnoticed as long as every region had its page fixed by
			// hand : only the offsets inside a page moved, and the placement
			// registry — which the real pass rewrites — carried the truth. The
			// day the builder was allowed to choose the PAGE too, the harvest
			// started naming pages that the disk never had, and the game
			// jumped into empty RAM.
			//
			// So the second pass replays the discovery with the first one's
			// measures : same layout as the real pass, same addresses, and a
			// harvest that describes the disk actually being written. It costs
			// one more run of a build whose every step is cached.
			Discovery measuring = discoveryPass(node, null, null);
			if (measuring.stop != null && measuring.measured.isEmpty()) {
				throw new Exception("discovery pass failed before measuring the layout — "
						+ measuring.stop.getMessage(), measuring.stop);
			}
			Discovery discovered = discoveryPass(node, measuring.measured,
					measuring.fileSizes);
			if (discovered.stop != null && discovered.measured.isEmpty()) {
				throw new Exception("discovery pass failed before measuring the layout — "
						+ discovered.stop.getMessage(), discovered.stop);
			}
			log.info("{} link symbols discovered ({} imported), ids assigned alphabetically",
					discovered.symbols.size(), discovered.imported.size());

			// The discovery passes write the same dist/ images the real pass
			// will, but resetTarget clears their registration : a target
			// refused BEFORE the real pass rewrote them would leave the
			// discovery's freshly timestamped images behind — exactly what
			// discardOutputs promises cannot happen. Keep their paths across
			// the reset so a refusal removes them too.
			java.util.List<java.nio.file.Path> discoveryOutputs =
					new ArrayList<java.nio.file.Path>(ctx.outputs.paths());

			// ids and defines are global to a target : restart them so that two
			// targets of the same game (fd, t2, ...) get identical ids, and so
			// that building "-t fd" alone or "-t sd,fd" yields the same image
			ctx.resetTarget();
			// the measures go in BEFORE the placement scan : the scan resolves
			// the layout too, and a scan that disagreed with it would bake
			// references against addresses nothing ever loads at
			ctx.regions.seedMeasured(discovered.measured);
			ctx.regions.seedFileSizes(discovered.fileSizes);
			com.widedot.m6809.gamebuilder.config.PlacementScan.run(node, ctx);
			ctx.linkSymbols.preseed(discovered.symbols);
			ctx.linkSymbols.preseedImports(discovered.imported);
			// the real pass bakes against the discovered offsets : declaration
			// order no longer decides whether a provider is resolvable, and a
			// symbol exported by several run-time alternatives is refused
			// deterministically instead of resolving to whichever came last
			ctx.staticLink.preseed(discovered.harvest);

			// The images are written as the target runs, but the checks that
			// close it come after — so a refused build would leave a freshly
			// timestamped disk in dist/ that boots into garbage. Anything this
			// target produced goes away with it.
			try {
				runTarget(node);
				if (ctx.linkSymbols.pruned > 0) {
					log.info("{} exports never imported, left out of the link data", ctx.linkSymbols.pruned);
				}
				// a file that dropped linkdata must not still be imported
				ctx.linkSymbols.checkImportsResolvable();
				// the declared RAM states : here, and not earlier, because it
				// takes the scenes of every directory of the target and the
				// measured sizes at once
				com.widedot.m6809.gamebuilder.plugin.layout.CompositionChecks.verify(ctx);
			} catch (Exception e) {
				for (java.nio.file.Path p : discoveryOutputs) {
					ctx.outputs.record(p);
				}
				discardOutputs(targetName);
				throw e;
			}
			reportLinkData(targetName);
			reportLinkedRefs(targetName);
			writeSeekReport(targetName);
			writeOccupancyReport(targetName);
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
			java.nio.file.Path staleRefs = linkedRefsPath(targetName);
			if (java.nio.file.Files.deleteIfExists(staleRefs)) {
				removed++;
				log.info("removed {} : it described an earlier build", staleRefs);
			}
			java.nio.file.Path staleMap = occupancyPath(targetName);
			if (java.nio.file.Files.deleteIfExists(staleMap)) {
				removed++;
				log.info("removed {} : it described an earlier build", staleMap);
			}
			java.nio.file.Path stalePool = poolMapPath(targetName);
			if (java.nio.file.Files.deleteIfExists(stalePool)) {
				removed++;
				log.info("removed {} : it described an earlier build", stalePool);
			}
			java.nio.file.Path staleSeek = seekReportPath(targetName);
			if (java.nio.file.Files.deleteIfExists(staleSeek)) {
				removed++;
				log.info("removed {} : it described an earlier build", staleSeek);
			}
		} catch (Exception e) {
			log.warn("could not remove the stale reports: {}", e.getMessage());
		}
		if (removed > 0) {
			log.error("target {} failed : {} output file(s) removed, dist holds nothing"
					+ " from this build", targetName, removed);
		}
	}

	private java.nio.file.Path seekReportPath(String targetName) {
		return java.nio.file.Paths.get(
				ctx.path + java.io.File.separator + ctx.settings.get("dist.dir"),
				"seek-report-" + targetName + ".txt");
	}

	/**
	 * What loading each scene costs the drive's head, from the media journal
	 * and the RAM map — see {@link com.widedot.m6809.gamebuilder.report.SeekReport}.
	 */
	private void writeSeekReport(String targetName) {
		if (ctx.ramMap.isEmpty() || ctx.occupancy.isEmpty()) {
			return;
		}
		java.nio.file.Path path = seekReportPath(targetName);
		try {
			String report = com.widedot.m6809.gamebuilder.report.SeekReport.render(targetName, ctx);
			java.nio.file.Files.createDirectories(path.getParent());
			java.nio.file.Files.writeString(path, report);
			log.info("seek report written to {}", path);
		} catch (Exception e) {
			log.warn("could not write the seek report: {}", e.getMessage());
		}
	}

	/**
	 * The interactive occupancy report : one static HTML page, two views —
	 * where each scene lands in RAM, and where every byte sits on the media.
	 * Replaces the ram-map text file, which could neither show a collision
	 * nor be filtered.
	 */
	private void writeOccupancyReport(String targetName) {
		if (ctx.ramMap.isEmpty() && ctx.occupancy.isEmpty()) {
			return;
		}
		java.nio.file.Path path = occupancyPath(targetName);
		try {
			java.nio.file.Files.createDirectories(path.getParent());
			java.nio.file.Files.writeString(path,
					com.widedot.m6809.gamebuilder.report.OccupancyReport.render(
							targetName, ctx));
			log.info("occupancy report written to {}", path);
		} catch (Exception e) {
			log.warn("could not write the occupancy report: {}", e.getMessage());
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
							targetName, ctx.ramMap, ctx.linkReport, declaredPoolSize(node),
							ctx.compositions));
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

	private java.nio.file.Path occupancyPath(String targetName) {
		return java.nio.file.Paths.get(
				ctx.path + java.io.File.separator + ctx.settings.get("dist.dir"),
				"occupancy-" + targetName + ".html");
	}

	private java.nio.file.Path linkReportPath(String targetName) {
		return java.nio.file.Paths.get(
				ctx.path + java.io.File.separator + ctx.settings.get("dist.dir"),
				"link-report-" + targetName + ".csv");
	}

	private java.nio.file.Path linkedRefsPath(String targetName) {
		return java.nio.file.Paths.get(
				ctx.path + java.io.File.separator + ctx.settings.get("dist.dir"),
				"linked-refs-" + targetName + ".csv");
	}

	/**
	 * Every named reference the loader will resolve at run time, WITH its
	 * cause — the report born with the derived link (see
	 * {@code docs/lang/en/symbols.md}, "The caused list").
	 *
	 * The link report says what link data costs per file ; this one says WHY
	 * each named reference still goes through the loader. Once baking is the
	 * default the list is short, and it is meant to be re-read : every line
	 * should be a boundary the author recognises (an exchangeable provider, a
	 * declared bake="none") — a surprising line is a name exported twice by
	 * mistake, which the derived routing turns into a silent link instead of
	 * a build error.
	 *
	 * Internal relocations carry no name to review ; the link report counts
	 * them per file.
	 */
	private void reportLinkedRefs(String targetName) {
		java.util.List<com.widedot.m6809.gamebuilder.spi.globals.StaticLink.LinkedRef> refs =
				ctx.staticLink.linkedRefs();

		int classified = 0;
		for (com.widedot.m6809.gamebuilder.spi.globals.StaticLink.LinkedRef r : refs) {
			if (r.classified) classified++;
		}
		if (!refs.isEmpty()) {
			log.info("resolved at load: {} named references ({} classified by bake=\"auto\","
					+ " {} declared bake=\"none\")", refs.size(), classified, refs.size() - classified);
			// the classified ones are the reviewable list — a declared none is
			// its own cause, a classification deserves its line
			for (com.widedot.m6809.gamebuilder.spi.globals.StaticLink.LinkedRef r : refs) {
				if (r.classified) {
					log.info("  {} in {} ({} site{}) : {}", r.symbol, r.consumer,
							r.count, r.count > 1 ? "s" : "", r.cause);
				}
			}
		}

		java.nio.file.Path csv = linkedRefsPath(targetName);
		if (refs.isEmpty()) {
			// nothing linked : no report to leave around describing an earlier build
			try {
				java.nio.file.Files.deleteIfExists(csv);
			} catch (Exception e) {
				log.warn("could not remove the stale caused list {}: {}", csv, e.getMessage());
			}
			return;
		}
		StringBuilder sb = new StringBuilder("file,symbol,sites,mode,cause\n");
		for (com.widedot.m6809.gamebuilder.spi.globals.StaticLink.LinkedRef r : refs) {
			sb.append(r.consumer).append(',')
			  .append(r.symbol).append(',')
			  .append(r.count).append(',')
			  .append(r.classified ? "auto" : "declared").append(',')
			  .append('"').append(r.cause.replace("\"", "\"\"")
					  .replace('\n', ' ').replace("\r", "")).append('"')
			  .append('\n');
		}
		try {
			java.nio.file.Files.createDirectories(csv.getParent());
			java.nio.file.Files.write(csv, sb.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));
			log.info("caused list written to {}", csv);
		} catch (Exception e) {
			// a report is never worth failing a build that otherwise succeeded
			log.warn("could not write the caused list to {}: {}", csv, e.getMessage());
		}
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
