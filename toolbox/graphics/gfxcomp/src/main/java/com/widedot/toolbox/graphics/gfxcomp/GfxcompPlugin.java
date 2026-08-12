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
			throw new Exception("<gfxcomp genindex> cannot be packed into pages : the index has"
					+ " to stay in one page, the one Img_Page_Index mounts to read it, while the"
					+ " code is what gets spread. Name the set with imageset=\"...\" here and"
					+ " index it with an <imageset> element in the direntry that holds it");
		}

		VideoMemory.memoryLinearBits = Attribute.getInteger(node, ctx, "linearbits", 4);
		VideoMemory.memoryPlanarBits = Attribute.getInteger(node, ctx, "planarbits", 8);
		VideoMemory.memoryLineBytes  = Attribute.getInteger(node, ctx, "linebytes", 40);
		VideoMemory.memoryNbPlanes   = Attribute.getInteger(node, ctx, "nbplanes", 2);
		VideoMemory.memoryPlaneDistance = Attribute.getInteger(node, ctx, "planedistance", 8192);

		// A spread set is indexed from elsewhere, so the geometry measured here
		// is handed over rather than written out : see ImageSets.
		String name = Attribute.getStringOpt(node, ctx, "imageset");
		ImageSet imageset = name == null ? null : new ImageSet(0, null);

		java.util.List<String[]> parts = new ArrayList<>();
		for (ImmutableNode child : imageNodes(node, ctx)) {
			for (String file : compile(child, ctx, gendir, imageset)) {
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
		if (imageset != null) {
			ctx.imageSets.declare(name, imageset);
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
		VideoMemory.memoryPlaneDistance = Attribute.getInteger(node, ctx, "planedistance", 8192);

		if (genindex != null && file == null) {
			throw new Exception("<gfxcomp genindex> also needs file, the direntry name the images "
			                  + "end up in : the index references their page through <file>$PAGE");
		}
		// A slice of a spread set : imageset= (without genindex) hands the
		// geometry over to the registry — several slices merge there — and the
		// single <imageset> element writes the whole index later, asking each
		// image for the page of ITS slice. This is what lets one set be cut
		// into files the arena ranges independently.
		String setName = Attribute.getStringOpt(node, ctx, "imageset");
		if (setName != null && genindex != null) {
			throw new Exception("<gfxcomp> takes genindex (the index lives here) or imageset"
			                  + " (the index lives with the <imageset> element), not both");
		}
		ImageSet imageset = genindex != null ? new ImageSet(0, file)
		                  : setName != null ? new ImageSet(0, null)
		                  : null;
		List<String> generated = new ArrayList<>();

		for (ImmutableNode child : imageNodes(node, ctx)) {
			generated.addAll(compile(child, ctx, gendir, imageset));
		}

		if (generated.isEmpty()) {
			throw new Exception("no <image> to compile in <gfxcomp>");
		}

		if (setName != null) {
			ctx.imageSets.declare(setName, imageset);
		} else if (imageset != null) {
			String index = ctx.path + File.separator + genindex;
			Files.createDirectories(Paths.get(index).getParent());
			com.widedot.m6809.gamebuilder.spi.globals.Machines.Machine machine =
					ctx.machines.required("<gfxcomp>");
			imageset.generate(index,
					new com.widedot.m6809.gamebuilder.spi.globals.ImageSets.PageByte(
							machine.pageExpr, machine.pageInclude));
			generated.add(index);
		}

		// section="none" for a host that has already opened one — a <block> of
		// a pageset, whose member source wraps every part alike. Nesting a
		// second SECTION there would close the member's.
		//
		// A slice exports every part it compiles : the index lives in ANOTHER
		// file and reaches the images through the linker — exactly what the
		// pageset member source did for its parts. Inline-index mode exports
		// nothing, the index being in the same assembly.
		return writeIncludes(gensource, generated,
				Attribute.getString(node, ctx, "section", "code"),
				setName != null);
	}

	private static List<String> compile(ImmutableNode node, BuildContext ctx, String gendir, ImageSet imageset)
			throws Exception {

		String name = Attribute.getString(node, ctx, "name");
		String filename = ctx.path + File.separator + Attribute.getString(node, ctx, "filename");
		Integer index = Attribute.getIntegerOpt(node, ctx, "index");
		String grid = Attribute.getStringOpt(node, ctx, "grid");

		if (grid != null) {
			// a tileset : the input is a sheet of grid-sized tiles, each one
			// compiled as its own image named <host>_<id>. Ids follow the v1
			// reading order — left to right, then top to bottom — which is the
			// order leanscroll writes the sheet in, so the tile indexes of its
			// map .bin land on the right symbols. The HOST — the direntry or
			// pageset carrying this gfxcomp — qualifies the name : host names
			// are unique per target by construction, so two stages slicing
			// same-named sheets never collide on their tile symbols, and a
			// <tilemap> names the host it consumes
			if (index != null) {
				throw new Exception("image " + name + " : grid and index are exclusive, a"
						+ " tileset is addressed by a <tilemap>, not by the imageset");
			}
			String host = ctx.staticLink.currentHost();
			List<String[]> selected = new ArrayList<>();
			int id = 0;
			for (String tile : slice(name, filename, grid, gendir)) {
				String tileName = (host != null ? host : name) + "_" + id++;
				selected.add(new String[] { tileName, tile });
			}
			List<String> files = encodeTiles(node, ctx, gendir, imageset, selected);
			if (files.isEmpty()) {
				throw new Exception("image " + name + " : the sheet yields no tile");
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

	/**
	 * The effective {@code <image>} nodes of a gfxcomp : literal children pass
	 * through, and each {@code <images>} row — the compact declaration (7b) —
	 * expands into one image per file of its SERIES directory.
	 *
	 * The contract, measured on the v1 reference :
	 * <ul>
	 * <li>the files, filtered by {@code match} (default *.png), are ordered by
	 *     their NN numeric prefix — the order IS the name, assigned from the
	 *     v1 d7 properties order at renaming time ;</li>
	 * <li>imageset indexes CONTINUE across rows and literal images alike — one
	 *     running counter for the whole gfxcomp, a literal {@code index=}
	 *     resetting it ;</li>
	 * <li>symbol names are {@code <base>_<n>} : base from {@code names=}, or
	 *     the series directory (its parent when the directory is the plain
	 *     {@code images/}), with one counter PER BASE so a mirror row of the
	 *     same directory continues the numbering ;</li>
	 * <li>each row composes its encoders : {@code encoder=} (bdraw if absent)
	 *     + {@code mirror=} + one entry per shift of {@code shifts=} — the
	 *     latter defaulting through the attribute cascade, so a target's
	 *     {@code <default name="images.shifts">} decides d7/t2 in ONE line
	 *     while any row may pin its own.</li>
	 * </ul>
	 */
	static List<ImmutableNode> imageNodes(ImmutableNode node, BuildContext ctx)
			throws Exception {

		boolean indexed = Attribute.getStringOpt(node, ctx, "genindex") != null
				|| Attribute.getStringOpt(node, ctx, "imageset") != null;
		List<ImmutableNode> images = new ArrayList<>();
		int nextIndex = 0;
		java.util.Map<String, Integer> baseCounters = new java.util.LinkedHashMap<>();

		for (ImmutableNode child : node.getChildren()) {
			if ("image".equals(child.getNodeName())) {
				Integer index = Attribute.getIntegerOpt(child, ctx, "index");
				if (index != null) {
					nextIndex = index + 1;
				}
				// a literal name of the <base>_<n> shape advances that base's
				// counter, so compact rows resume after hand-written exceptions
				String name = Attribute.getStringOpt(child, ctx, "name");
				if (name != null && name.matches(".*_\\d+")) {
					int cut = name.lastIndexOf('_');
					String base = name.substring(0, cut);
					int n = Integer.parseInt(name.substring(cut + 1));
					baseCounters.merge(base, n + 1, Math::max);
				}
				images.add(child);
				continue;
			}
			if (!"images".equals(child.getNodeName())) {
				throw new Exception("Element <" + child.getNodeName() + "> is not valid inside <gfxcomp>");
			}

			String dir = Attribute.getString(child, ctx, "dir");
			String match = Attribute.getString(child, ctx, "match", "*.png");
			String encoder = Attribute.getString(child, ctx, "encoder", Image.TYPE_BDRAW);
			String mirror = Attribute.getString(child, ctx, "mirror", Mirror.NONE);
			String shifts = Attribute.getString(child, ctx, "shifts", "0");
			String position = Attribute.getStringOpt(child, ctx, "position");
			String planes = Attribute.getStringOpt(child, ctx, "planes");
			String base = Attribute.getStringOpt(child, ctx, "names");
			if (base == null) {
				Path p = Paths.get(dir).getFileName() != null ? Paths.get(dir) : null;
				String last = p.getFileName().toString();
				base = "images".equals(last) && p.getParent() != null
						? p.getParent().getFileName().toString() : last;
			}

			File series = new File(ctx.path + File.separator + dir);
			if (!series.isDirectory()) {
				throw new Exception(ctx.sources.locate(child) + ": <images> dir '" + dir
						+ "' is not a directory");
			}
			java.nio.file.PathMatcher glob = java.nio.file.FileSystems.getDefault()
					.getPathMatcher("glob:" + match);
			java.util.TreeMap<Integer, String> ordered = new java.util.TreeMap<>();
			for (File f : series.listFiles()) {
				if (!f.isFile() || !glob.matches(Paths.get(f.getName()))) {
					continue;
				}
				java.util.regex.Matcher nn = java.util.regex.Pattern
						.compile("^(\\d+)").matcher(f.getName());
				if (!nn.find()) {
					throw new Exception(ctx.sources.locate(child) + ": <images> file '"
							+ dir + "/" + f.getName() + "' has no NN order prefix — the"
							+ " order is the name (see analyse-images-7b)");
				}
				String twin = ordered.put(Integer.parseInt(nn.group(1)), f.getName());
				if (twin != null) {
					throw new Exception(ctx.sources.locate(child) + ": <images> files '"
							+ twin + "' and '" + f.getName() + "' share order prefix "
							+ nn.group(1) + " in '" + dir + "'");
				}
			}
			if (ordered.isEmpty()) {
				throw new Exception(ctx.sources.locate(child) + ": <images> matches no file"
						+ " in '" + dir + "' (match=" + match + ")");
			}

			for (String file : ordered.values()) {
				int n = baseCounters.merge(base, 1, Integer::sum) - 1;
				ImmutableNode.Builder image = new ImmutableNode.Builder();
				image.name("image")
					 .addAttribute("name", base + "_" + n)
					 .addAttribute("filename", dir + "/" + file);
				if (indexed) {
					image.addAttribute("index", String.valueOf(nextIndex++));
				}
				for (String shift : shifts.split(",")) {
					ImmutableNode.Builder enc = new ImmutableNode.Builder();
					enc.name("encoder")
					   .addAttribute("name", encoder)
					   .addAttribute("mirror", mirror)
					   .addAttribute("shift", shift.trim());
					if (position != null) enc.addAttribute("position", position);
					if (planes != null)   enc.addAttribute("planes", planes);
					image.addChild(enc.create());
				}
				images.add(image.create());
			}
		}
		return images;
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

	/**
	 * The tiles of a sheet, encoded concurrently. Each tile's optimizer is
	 * seeded on its own, so the code produced is byte for byte the code of the
	 * serial loop — the fan out only spends the cores. The build context is
	 * read on the caller thread (workers get plain values), and the imageset
	 * registration replays in tile order once every future has landed.
	 */
	private static List<String> encodeTiles(ImmutableNode node, BuildContext ctx, String gendir,
			ImageSet imageset, List<String[]> tiles) throws Exception {

		List<String[]> specs = new ArrayList<>();
		for (ImmutableNode child : node.getChildren()) {
			if (!"encoder".equals(child.getNodeName())) {
				throw new Exception("Element <" + child.getNodeName() + "> is not valid inside <image>");
			}
			specs.add(new String[] {
					Attribute.getString(child, ctx, "name", Image.TYPE_DRAW),
					Attribute.getString(child, ctx, "mirror", Mirror.NONE),
					String.valueOf(Attribute.getInteger(child, ctx, "shift", 0)),
					Attribute.getString(child, ctx, "position", Image.POSITION_CENTER),
					Attribute.getString(child, ctx, "planes", Image.PLANES_POINTER) });
		}
		if (specs.isEmpty()) {
			throw new Exception("tileset has no <encoder>");
		}

		int threads = Math.min(8, Runtime.getRuntime().availableProcessors());
		java.util.concurrent.ExecutorService pool =
				java.util.concurrent.Executors.newFixedThreadPool(threads);
		try {
			List<java.util.concurrent.Future<Object[]>> futures = new ArrayList<>();
			for (String[] t : tiles) {
				futures.add(pool.submit(() -> {
					List<String> produced = new ArrayList<>();
					List<Image> images = new ArrayList<>();
					for (String[] spec : specs) {
						Image image = new Image(t[0], null, t[1], spec[0], spec[1],
								Integer.valueOf(spec[2]), spec[3], spec[4]);
						image.encode(gendir);
						images.add(image);
						produced.add(gendir + File.separator + image.getFullName() + ".asm");
						String erase = gendir + File.separator + image.getFullName() + "_erase.asm";
						if (Files.exists(Paths.get(erase))) {
							produced.add(erase);
						}
					}
					return new Object[] { produced, images };
				}));
			}
			List<String> files = new ArrayList<>();
			for (java.util.concurrent.Future<Object[]> future : futures) {
				Object[] result;
				try {
					result = future.get();
				} catch (java.util.concurrent.ExecutionException e) {
					throw e.getCause() instanceof Exception ? (Exception) e.getCause() : e;
				}
				@SuppressWarnings("unchecked")
				List<String> produced = (List<String>) result[0];
				files.addAll(produced);
				if (imageset != null) {
					for (Object image : (List<?>) result[1]) {
						imageset.addImage((Image) image);
					}
				}
			}
			return files;
		} finally {
			pool.shutdown();
		}
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
			String planes   = Attribute.getString(child, ctx, "planes", Image.PLANES_POINTER);

			Image image = new Image(name, index, filename, encoder, mirror, shift, position, planes);
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

	private static File writeIncludes(String gensource, List<String> files, String section)
			throws Exception {
		return writeIncludes(gensource, files, section, false);
	}

	private static File writeIncludes(String gensource, List<String> files, String section,
			boolean exportParts) throws Exception {
		// the compiled code carries no SECTION of its own : the unit owns it,
		// and section="none" says the host already opened it
		boolean wrap = !"none".equals(section);
		StringBuilder source = new StringBuilder("* Generated by gfxcomp" + System.lineSeparator());
		if (exportParts) {
			// EXPORT stays outside the section, as everywhere else
			for (String file : files) {
				String base = file.substring(file.lastIndexOf(File.separatorChar) + 1,
						file.length() - ".asm".length());
				source.append("adr_").append(base).append(" EXPORT")
				      .append(System.lineSeparator());
			}
		}
		if (wrap) {
			source.append(" SECTION ").append(section).append(System.lineSeparator());
		}
		for (String file : files) {
			source.append("        INCLUDE \"").append(file).append('"').append(System.lineSeparator());
		}
		if (wrap) {
			source.append(" ENDSECTION").append(System.lineSeparator());
		}
		Path path = Paths.get(gensource);
		if (path.getParent() != null) {
			Files.createDirectories(path.getParent());
		}
		Files.writeString(path, source.toString());
		return path.toFile();
	}
}
