package com.widedot.m6809.gamebuilder.plugin.scene;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
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
 */
@Slf4j
public class ScenePlugin {

	public static void run(ImmutableNode node, BuildContext ctx, MediaDataInterface media,
			String gensymbols, Set<String> directoryNames) throws Exception {

		log.debug("Processing scene ...");

		String name = Attribute.getString(node, ctx, "name");
		String section = Attribute.getString(node, ctx, "section");
		String gensource = Attribute.getString(node, ctx, "gensource", "gen/scenes/" + name + ".asm");

		List<SceneGenerator.Placed> placed = new ArrayList<SceneGenerator.Placed>();
		List<String> exportOnly = new ArrayList<String>();
		Set<String> usedRegions = new HashSet<String>();
		List<String> errors = new ArrayList<String>();

		for (ImmutableNode child : node.getChildren()) {
			if (!"load".equals(child.getNodeName())) {
				throw new Exception(ctx.sources.locate(child) + ": <scene> only contains <load> elements, found <"
						+ child.getNodeName() + ">");
			}
			String where = ctx.sources.locate(child) + ": scene " + name;

			String loadName = Attribute.getString(child, ctx, "name");
			String regionName = Attribute.getStringOpt(child, ctx, "region");
			Integer page = Attribute.getIntegerOpt(child, ctx, "page");
			Integer address = Attribute.getIntegerOpt(child, ctx, "address");

			if (!directoryNames.contains(loadName)) {
				errors.add(where + ": load '" + loadName + "' references no direntry or scene of this directory");
				continue;
			}

			if (regionName != null) {
				if (page != null || address != null) {
					errors.add(where + ": load '" + loadName + "' gives both a region and a raw destination");
					continue;
				}
				Regions.Region region = ctx.regions.get(regionName);
				if (region == null) {
					errors.add(where + ": unknown region '" + regionName + "' (layout declares: "
							+ ctx.regions.names() + ")");
					continue;
				}
				if (!usedRegions.add(regionName)) {
					errors.add(where + ": region '" + regionName + "' is loaded twice ; a region takes one"
							+ " direntry per scene, make it a multi-asm direntry instead");
					continue;
				}
				placed.add(new SceneGenerator.Placed(region.page, region.address, loadName));
			} else if (page != null || address != null) {
				if (page == null || address == null) {
					errors.add(where + ": load '" + loadName + "' needs both page and address");
					continue;
				}
				placed.add(new SceneGenerator.Placed(page, address, loadName));
			} else {
				exportOnly.add(loadName);
			}
		}

		if (!errors.isEmpty()) {
			throw new Exception("Invalid scene:\n  " + String.join("\n  ", errors));
		}

		// generate the table source
		String tableFile = gensource.endsWith(".asm")
				? gensource.substring(0, gensource.length() - 4) + ".table.asm"
				: gensource + ".table.asm";
		String tablePath = ctx.path + File.separator + tableFile;
		Files.createDirectories(Paths.get(FileUtil.getDir(tablePath)));
		Files.write(Paths.get(tablePath),
				SceneGenerator.generate(name, placed, exportOnly).getBytes(StandardCharsets.UTF_8));

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
