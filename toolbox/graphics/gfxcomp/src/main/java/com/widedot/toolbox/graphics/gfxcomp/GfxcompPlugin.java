package com.widedot.toolbox.graphics.gfxcomp;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.toolbox.graphics.gfxcomp.imageset.ImageSet;
import com.widedot.toolbox.graphics.gfxcomp.setting.VideoMemory;
import com.widedot.toolbox.graphics.gfxcomp.transformer.mirror.Mirror;

import lombok.extern.slf4j.Slf4j;

/**
 * Handler for the &lt;gfxcomp&gt; element : compiles PNGs into 6809 code inside
 * a &lt;lwasm&gt; unit.
 *
 * The compiler produces one source per image variant plus the imageset index,
 * while a source unit is a single file, so what comes back is a generated file
 * of INCLUDE lines. The parts stay on disk under their own names, which is what
 * makes them comparable with the v1 generator's output (see bench/run.sh).
 *
 * Placement is left to the load time linker: the generated code carries no ORG,
 * and the index references it through the adr_/pge_ symbols the linker resolves.
 */
@Slf4j
public class GfxcompPlugin {

	/**
	 * The compiled parts, each with the symbol it defines — what a pageset
	 * packs into pages.
	 *
	 * The unit of packing is one generated source, because that is the
	 * granularity at which the builder can reassemble : cutting an already
	 * assembled binary would split routines and lose relocations, while
	 * regrouping sources cannot. Each entry is {path, symbol}.
	 */
	public static java.util.List<String[]> getParts(ImmutableNode node, BuildContext ctx)
			throws Exception {

		String gendir = ctx.path + File.separator + Attribute.getString(node, ctx, "gendir");
		if (Attribute.getStringOpt(node, ctx, "genindex") != null) {
			throw new Exception("<gfxcomp genindex> cannot be packed into pages : an imageset"
					+ " index reads one page from <file>$PAGE for the whole set");
		}

		VideoMemory.memoryLinearBits = Attribute.getInteger(node, ctx, "linearbits", 4);
		VideoMemory.memoryPlanarBits = Attribute.getInteger(node, ctx, "planarbits", 8);
		VideoMemory.memoryLineBytes  = Attribute.getInteger(node, ctx, "linebytes", 40);
		VideoMemory.memoryNbPlanes   = Attribute.getInteger(node, ctx, "nbplanes", 2);

		java.util.List<String[]> parts = new ArrayList<>();
		for (ImmutableNode child : node.getChildren()) {
			if (!"image".equals(child.getNodeName())) {
				throw new Exception("Element <" + child.getNodeName() + "> is not valid inside <gfxcomp>");
			}
			for (String file : compile(child, ctx, gendir, null)) {
				if (file.endsWith("_exports.asm")) {
					continue; // the export block belongs with whichever part is emitted
				}
				String base = file.substring(file.lastIndexOf(File.separatorChar) + 1,
						file.length() - ".asm".length());
				parts.add(new String[] { file, "adr_" + base });
			}
		}
		if (parts.isEmpty()) {
			throw new Exception("no <image> to compile in <gfxcomp>");
		}
		return parts;
	}

	public static File getFile(ImmutableNode node, BuildContext ctx) throws Exception {

		String gendir = ctx.path + File.separator + Attribute.getString(node, ctx, "gendir");
		String gensource = ctx.path + File.separator + Attribute.getString(node, ctx, "gensource");
		String genindex = Attribute.getStringOpt(node, ctx, "genindex");
		String file = Attribute.getStringOpt(node, ctx, "file");

		VideoMemory.memoryLinearBits = Attribute.getInteger(node, ctx, "linearbits", 4);
		VideoMemory.memoryPlanarBits = Attribute.getInteger(node, ctx, "planarbits", 8);
		VideoMemory.memoryLineBytes  = Attribute.getInteger(node, ctx, "linebytes", 40);
		VideoMemory.memoryNbPlanes   = Attribute.getInteger(node, ctx, "nbplanes", 2);

		if (genindex != null && file == null) {
			throw new Exception("<gfxcomp genindex> also needs file, the direntry name the images "
			                  + "end up in : the index references their page through <file>$PAGE");
		}
		ImageSet imageset = genindex == null ? null : new ImageSet(0, file);
		List<String> generated = new ArrayList<>();

		for (ImmutableNode child : node.getChildren()) {
			if (!"image".equals(child.getNodeName())) {
				throw new Exception("Element <" + child.getNodeName() + "> is not valid inside <gfxcomp>");
			}
			generated.addAll(compile(child, ctx, gendir, imageset));
		}

		if (generated.isEmpty()) {
			throw new Exception("no <image> to compile in <gfxcomp>");
		}

		if (imageset != null) {
			String index = ctx.path + File.separator + genindex;
			Files.createDirectories(Paths.get(index).getParent());
			imageset.generate(index);
			generated.add(index);
		}

		return writeIncludes(gensource, generated);
	}

	private static List<String> compile(ImmutableNode node, BuildContext ctx, String gendir, ImageSet imageset)
			throws Exception {

		String name = Attribute.getString(node, ctx, "name");
		String filename = ctx.path + File.separator + Attribute.getString(node, ctx, "filename");
		Integer index = Attribute.getIntegerOpt(node, ctx, "index");
		String grid = Attribute.getStringOpt(node, ctx, "grid");
		String range = Attribute.getStringOpt(node, ctx, "range");

		if (grid != null) {
			// a tileset : the input is a sheet of grid-sized tiles, each one
			// compiled as its own image named <name>_<id>. Ids follow the v1
			// reading order — left to right, then top to bottom — which is the
			// order leanscroll writes the sheet in, so the tile indexes of its
			// map .bin land on the right symbols
			if (index != null) {
				throw new Exception("image " + name + " : grid and index are exclusive, a"
						+ " tileset is addressed by a <tilemap>, not by the imageset");
			}
			// A tileset bigger than a page is declared as several units, each
			// taking a range of the same sheet ; the tile ids stay those of
			// the sheet, so the map keeps naming them the same way and each
			// entry resolves its own page. The slicing itself is done in full
			// either way — it is cheap, and it keeps the ids independent of
			// where the author put the cuts.
			int[] bounds = parseRange(name, range);
			List<String> files = new ArrayList<>();
			for (String tile : slice(name, filename, grid, gendir)) {
				String tileName = tile.substring(tile.lastIndexOf(File.separatorChar) + 1,
						tile.length() - ".png".length());
				int id = Integer.parseInt(tileName.substring(name.length() + 1));
				if (id < bounds[0] || id > bounds[1]) {
					continue;
				}
				files.addAll(encode(node, ctx, gendir, imageset, tileName, tile, null));
			}
			if (files.isEmpty()) {
				throw new Exception("image " + name + " : range '" + range
						+ "' selects no tile of the sheet");
			}
			// a tileset is consumed by name — a <tilemap> baking adr_ symbols
			// against this direntry's placement — and has no imageset index to
			// export them, so the entry points are exported here. Nothing
			// imports them through the loader : pruning keeps them off disk
			StringBuilder exports = new StringBuilder("* Generated by gfxcomp : the tile entry points"
					+ System.lineSeparator());
			for (String file : files) {
				String base = file.substring(file.lastIndexOf(File.separatorChar) + 1,
						file.length() - ".asm".length());
				exports.append("adr_").append(base).append(" EXPORT").append(System.lineSeparator());
			}
			Path exportsFile = Paths.get(gendir, name + "_exports.asm");
			Files.writeString(exportsFile, exports.toString());
			files.add(exportsFile.toString());
			return files;
		}
		return encode(node, ctx, gendir, imageset, name, filename, index);
	}

	/** the inclusive tile id bounds a unit takes of its sheet ; everything by default */
	private static int[] parseRange(String name, String range) throws Exception {
		if (range == null) {
			return new int[] { 0, Integer.MAX_VALUE };
		}
		String[] parts = range.split("-");
		try {
			int from = Integer.parseInt(parts[0].trim());
			int to = parts.length == 1 ? from : Integer.parseInt(parts[1].trim());
			if (parts.length > 2 || to < from) {
				throw new NumberFormatException();
			}
			return new int[] { from, to };
		} catch (NumberFormatException e) {
			throw new Exception("image " + name + " : range must be <first>-<last> tile ids,"
					+ " got '" + range + "'");
		}
	}

	/** cut a sheet into grid-sized tile PNGs, returning their paths in id order */
	private static List<String> slice(String name, String filename, String grid, String gendir)
			throws Exception {

		String[] dims = grid.split("x");
		if (dims.length != 2) {
			throw new Exception("image " + name + " : grid must be <width>x<height>, got '" + grid + "'");
		}
		int tileWidth = Integer.parseInt(dims[0]);
		int tileHeight = Integer.parseInt(dims[1]);

		java.awt.image.BufferedImage sheet = javax.imageio.ImageIO.read(new File(filename));
		if (sheet.getWidth() % tileWidth != 0 || sheet.getHeight() % tileHeight != 0) {
			throw new Exception("image " + name + " : sheet " + sheet.getWidth() + "x"
					+ sheet.getHeight() + " is not a whole number of " + grid + " tiles");
		}
		int columns = sheet.getWidth() / tileWidth;
		int rows = sheet.getHeight() / tileHeight;

		Path dir = Paths.get(gendir, name + "_tiles");
		Files.createDirectories(dir);
		List<String> tiles = new ArrayList<>();
		for (int id = 0; id < columns * rows; id++) {
			// getSubimage keeps the indexed colour model, so the tile PNGs
			// stay 8 bit indexed like their sheet
			java.awt.image.BufferedImage tile = sheet.getSubimage(
					(id % columns) * tileWidth, (id / columns) * tileHeight, tileWidth, tileHeight);
			File out = dir.resolve(name + "_" + id + ".png").toFile();
			javax.imageio.ImageIO.write(tile, "png", out);
			tiles.add(out.getPath());
		}
		log.info("gfxcomp sliced {} into {} tiles of {}", name, tiles.size(), grid);
		return tiles;
	}

	private static List<String> encode(ImmutableNode node, BuildContext ctx, String gendir,
			ImageSet imageset, String name, String filename, Integer index) throws Exception {

		List<String> files = new ArrayList<>();
		for (ImmutableNode child : node.getChildren()) {
			if (!"encoder".equals(child.getNodeName())) {
				throw new Exception("Element <" + child.getNodeName() + "> is not valid inside <image>");
			}
			String encoder  = Attribute.getString(child, ctx, "name", Image.TYPE_DRAW);
			String mirror   = Attribute.getString(child, ctx, "mirror", Mirror.NONE);
			Integer shift   = Attribute.getInteger(child, ctx, "shift", 0);
			String position = Attribute.getString(child, ctx, "position", Image.POSITION_CENTER);

			Image image = new Image(name, index, filename, encoder, mirror, shift, position);
			image.encode(gendir);
			if (imageset != null) {
				imageset.addImage(image);
			}

			log.debug("gfxcomp compiled {} as {}", name, image.getVariant());
			files.add(gendir + File.separator + image.getFullName() + ".asm");
			String erase = gendir + File.separator + image.getFullName() + "_erase.asm";
			if (Files.exists(Paths.get(erase))) {
				files.add(erase);
			}
		}

		if (files.isEmpty()) {
			throw new Exception("image " + name + " has no <encoder>");
		}
		return files;
	}

	private static File writeIncludes(String gensource, List<String> files) throws Exception {
		// the compiled code carries no SECTION of its own : the unit owns it
		StringBuilder source = new StringBuilder("* Generated by gfxcomp" + System.lineSeparator());
		source.append(" SECTION code").append(System.lineSeparator());
		for (String file : files) {
			source.append("        INCLUDE \"").append(file).append('"').append(System.lineSeparator());
		}
		source.append(" ENDSECTION").append(System.lineSeparator());
		Path path = Paths.get(gensource);
		if (path.getParent() != null) {
			Files.createDirectories(path.getParent());
		}
		Files.writeString(path, source.toString());
		return path.toFile();
	}
}
