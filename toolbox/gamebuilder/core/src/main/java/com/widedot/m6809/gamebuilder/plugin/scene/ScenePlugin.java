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
 * The generated table goes through the regular file pipeline : a scene IS
 * a file (raw, uncompressed, one id block), only its source is produced
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
			String gensymbols, Set<String> directoryNames, Map<String, int[]> idBlocks,
			List<SceneCheck> pending) throws Exception {

		log.debug("Processing scene ...");

		String name = Attribute.getString(node, ctx, "name");
		String section = Attribute.getString(node, ctx, "section");
		String gensource = Attribute.getString(node, ctx, "gensource", "gen/scenes/" + name + ".asm");

		List<SceneGenerator.Placed> placed = new ArrayList<SceneGenerator.Placed>();
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

			if (!directoryNames.contains(loadName)) {
				errors.add(where + ": scene " + name + ": load '" + loadName
						+ "' references no file or scene of this directory");
				continue;
			}

			// the scene says WHO is in memory ; the file says WHERE it lives.
			// A load is a name — its destination is the file's attributed
			// place (arena / region / page+address), the same in every scene
			// that loads it. The per-load destination form is gone (4c).
			com.widedot.m6809.gamebuilder.spi.globals.FilePlaces.Place attributed =
					ctx.filePlaces.get(loadName);

			// a collection the packer CUT is one authored load and several
			// entries : the scene simply places each member where the packing
			// put it (the flow already guarantees the chunks never overlap)
			List<com.widedot.m6809.gamebuilder.spi.globals.Cuts.Member> members =
					ctx.cuts.members(loadName);
			if (members != null) {
				String setPlace = attributed == null ? null
						: (attributed.region != null ? attributed.region : attributed.arena);
				for (com.widedot.m6809.gamebuilder.spi.globals.Cuts.Member member : members) {
					placed.add(new SceneGenerator.Placed(member.page, member.address, member.name));
					check.loads.add(new SceneCheck.Load(member.name, SceneCheck.Kind.PLACED,
							member.page, member.address, null, setPlace, where));
				}
				continue;
			}

			if (attributed != null && attributed.arena != null) {
				Regions.Region arena = ctx.regions.get(attributed.arena);
				if (arena == null || !arena.packed) {
					errors.add(where + ": scene " + name + ": '" + loadName
							+ "' declares unknown arena '" + attributed.arena
							+ "' (layout declares: " + ctx.regions.names() + ")");
					continue;
				}
				int[] at = ctx.regions.filePlacement(loadName);
				if (at == null) {
					errors.add(where + ": scene " + name + ": '" + loadName
							+ "' was not ranged into arena '" + attributed.arena + "'");
					continue;
				}
				placed.add(new SceneGenerator.Placed(at[0], at[1], loadName));
				check.loads.add(new SceneCheck.Load(loadName, SceneCheck.Kind.PLACED,
						at[0], at[1], null, attributed.arena, where));
				continue;
			}

			if (attributed != null && attributed.region != null) {
				Regions.Region region = ctx.regions.get(attributed.region);
				if (region == null) {
					errors.add(where + ": scene " + name + ": '" + loadName
							+ "' declares unknown region '" + attributed.region
							+ "' (layout declares: " + ctx.regions.names() + ")");
					continue;
				}
				if (!usedRegions.add(attributed.region)) {
					errors.add(where + ": scene " + name + ": region '" + attributed.region
							+ "' is loaded twice ; a region takes one file per scene, make it"
							+ " a multi-asm file — or use an <arena> if it takes a list");
					continue;
				}
				placed.add(new SceneGenerator.Placed(region.page, region.address, loadName));
				check.loads.add(new SceneCheck.Load(loadName, SceneCheck.Kind.PLACED,
						region.page, region.address, region.size, attributed.region, where));
			} else if (attributed != null && attributed.page != null) {
				placed.add(new SceneGenerator.Placed(attributed.page, attributed.address, loadName));
				check.loads.add(new SceneCheck.Load(loadName, SceneCheck.Kind.PLACED,
						attributed.page, attributed.address, null, null, where));
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
				SceneGenerator.generate(name, placed, exportOnly, idBlocks)
						.getBytes(StandardCharsets.UTF_8));

		// hand the table to the regular file pipeline, wired exactly like
		// the handwritten scenes : file id equates first, then the table.
		// codec is pinned to none : the loader reads a scene table straight
		// after loader.file.load, the decompression pass only runs on the
		// files the table lists — a compressed table would be walked as
		// garbage (and the directory reservation counts a scene as one block)
		ImmutableNode equates = new ImmutableNode.Builder()
				.name("asm").addAttribute("filename", gensymbols).create();
		ImmutableNode table = new ImmutableNode.Builder()
				.name("asm").addAttribute("filename", tableFile).create();
		ImmutableNode lwasm = new ImmutableNode.Builder()
				.name("lwasm").addAttribute("format", "raw").addAttribute("gensource", gensource)
				.addChild(equates).addChild(table).create();
		ImmutableNode file = new ImmutableNode.Builder()
				.name("file").addAttribute("name", name).addAttribute("section", section)
				.addAttribute("codec", "none")
				.addChild(lwasm).create();

		DirEntryPlugin.run(file, ctx, media);

		log.debug("End of processing scene");
	}
}
