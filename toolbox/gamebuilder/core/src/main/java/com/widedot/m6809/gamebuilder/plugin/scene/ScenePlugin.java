package com.widedot.m6809.gamebuilder.plugin.scene;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.plugin.direntry.DirEntryPlugin;
import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.globals.Regions;
import com.widedot.m6809.gamebuilder.spi.media.MediaDataInterface;
import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;

/**
 * A declared scene : the table the loader consumes is generated instead of
 * handwritten, and the destinations come from the layout regions, so a wrong
 * page or address becomes a build error instead of a runtime corruption.
 *
 * The generated table goes through the regular direntry pipeline : a scene IS
 * a direntry (raw, uncompressed, one id block), only its source is produced
 * here. The directory's gensymbols file provides the file id equates, exactly
 * like the handwritten configurations wired it by hand.
 *
 * What can be checked without sizes is checked here ; everything that needs
 * the built sizes (budgets, in-scene overlaps, export-only coherence) is
 * recorded as a {@link SceneCheck} and verified by the directory once all its
 * entries are built.
 */
@Slf4j
public class ScenePlugin {

	public static void run(ImmutableNode node, BuildContext ctx, MediaDataInterface media,
			String gensymbols, Set<String> directoryNames, List<SceneCheck> pending) throws Exception {

		log.debug("Processing scene ...");

		String name = Attribute.getString(node, ctx, "name");
		String section = Attribute.getString(node, ctx, "section");
		String gensource = Attribute.getString(node, ctx, "gensource", "gen/scenes/" + name + ".asm");

		List<SceneGenerator.Placed> placed = new ArrayList<SceneGenerator.Placed>();
		Map<String, SceneGenerator.Bulk> bulks = new LinkedHashMap<String, SceneGenerator.Bulk>();
		List<String> exportOnly = new ArrayList<String>();
		Set<String> usedRegions = new HashSet<String>();
		List<String> errors = new ArrayList<String>();
		SceneCheck check = new SceneCheck(name);

		for (ImmutableNode child : node.getChildren()) {
			if (!"load".equals(child.getNodeName())) {
				throw new Exception(ctx.sources.locate(child) + ": <scene> only contains <load> elements, found <"
						+ child.getNodeName() + ">");
			}
			String where = ctx.sources.locate(child);

			String loadName = Attribute.getString(child, ctx, "name");
			String regionName = Attribute.getStringOpt(child, ctx, "region");
			Integer page = Attribute.getIntegerOpt(child, ctx, "page");
			Integer address = Attribute.getIntegerOpt(child, ctx, "address");

			if (!directoryNames.contains(loadName)) {
				errors.add(where + ": scene " + name + ": load '" + loadName
						+ "' references no direntry or scene of this directory");
				continue;
			}

			if (regionName != null) {
				if (page != null || address != null) {
					errors.add(where + ": scene " + name + ": load '" + loadName
							+ "' gives both a region and a raw destination");
					continue;
				}
				Regions.Region region = ctx.regions.get(regionName);
				if (region == null) {
					errors.add(where + ": scene " + name + ": unknown region '" + regionName
							+ "' (layout declares: " + ctx.regions.names() + ")");
					continue;
				}
				if (region.bulk) {
					// a bulk region takes a whole ordered list
					bulks.computeIfAbsent(regionName,
							k -> new SceneGenerator.Bulk(region.page, region.address, new ArrayList<String>()))
						.symbols.add(loadName);
					check.loads.add(new SceneCheck.Load(loadName, SceneCheck.Kind.BULK,
							region.page, region.address, region.size, regionName, where));
				} else {
					if (!usedRegions.add(regionName)) {
						errors.add(where + ": scene " + name + ": region '" + regionName
								+ "' is loaded twice ; a region takes one direntry per scene, make it"
								+ " a multi-asm direntry — or declare the region bulk if it takes a list");
						continue;
					}
					placed.add(new SceneGenerator.Placed(region.page, region.address, loadName));
					check.loads.add(new SceneCheck.Load(loadName, SceneCheck.Kind.PLACED,
							region.page, region.address, region.size, regionName, where));
				}
			} else if (page != null || address != null) {
				if (page == null || address == null) {
					errors.add(where + ": scene " + name + ": load '" + loadName
							+ "' needs both page and address");
					continue;
				}
				placed.add(new SceneGenerator.Placed(page, address, loadName));
				check.loads.add(new SceneCheck.Load(loadName, SceneCheck.Kind.PLACED,
						page, address, null, null, where));
			} else {
				exportOnly.add(loadName);
				check.loads.add(new SceneCheck.Load(loadName, SceneCheck.Kind.EXPORT_ONLY,
						0, 0, null, null, where));
			}
		}

		if (!errors.isEmpty()) {
			throw new Exception("Invalid scene:\n  " + String.join("\n  ", errors));
		}
		pending.add(check);

		// generate the table source
		String tableFile = gensource.endsWith(".asm")
				? gensource.substring(0, gensource.length() - 4) + ".table.asm"
				: gensource + ".table.asm";
		String tablePath = ctx.path + File.separator + tableFile;
		Files.createDirectories(Paths.get(FileUtil.getDir(tablePath)));
		Files.write(Paths.get(tablePath),
				SceneGenerator.generate(name, placed, new ArrayList<SceneGenerator.Bulk>(bulks.values()),
						exportOnly).getBytes(StandardCharsets.UTF_8));

		// hand the table to the regular direntry pipeline, wired exactly like
		// the handwritten scenes : file id equates first, then the table
		ImmutableNode equates = new ImmutableNode.Builder()
				.name("asm").addAttribute("filename", gensymbols).create();
		ImmutableNode table = new ImmutableNode.Builder()
				.name("asm").addAttribute("filename", tableFile).create();
		ImmutableNode lwasm = new ImmutableNode.Builder()
				.name("lwasm").addAttribute("format", "raw").addAttribute("gensource", gensource)
				.addChild(equates).addChild(table).create();
		ImmutableNode direntry = new ImmutableNode.Builder()
				.name("direntry").addAttribute("name", name).addAttribute("section", section)
				.addChild(lwasm).create();

		DirEntryPlugin.run(direntry, ctx, media);

		log.debug("End of processing scene");
	}
}
