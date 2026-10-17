package com.widedot.m6809.gamebuilder.plugin.tilemap;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.TreeSet;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;

import lombok.extern.slf4j.Slf4j;

/**
 * Handler for the &lt;tilecols&gt; element : the SPARSE COLUMN table of a tile
 * index map, the alternative to &lt;tilemap&gt; for the column scroll engine
 * (engine/graphics/tilemap/horizontal-scroll/scroll-columns.asm).
 *
 * Same input as &lt;tilemap&gt; (leanscroll's column-major index map), but
 * instead of one three-byte cell per index, the table holds one word per
 * column pointing at the column's list of FULL cells only :
 *
 *     label        fdb   label.c0, label.c1, ...
 *     label.c0     fcb   page          fdb   adr_tile     fdb   row*rowstep
 *                  ...
 *                  fcb   0
 *
 * The three tile bytes come first, in &lt;tilemap&gt;'s order, so the patch
 * primitive rewrites them the same way. A column listed in `dense` is emitted
 * with ALL its rows — the empty ones pointing the null tile — so the cells an
 * animation rewrites keep a fixed address (row x 5 from the column's entry).
 *
 * Measured on r-type (10 to 37 % full cells) the table weighs 40 to 50 % of
 * the dense one, and the scroll never visits an empty cell.
 *
 * `behind` names a mask (one byte per map cell, column major like the map,
 * non zero = the cell is drawn BEHIND the sprites) : the table under `label`
 * then holds the other cells only, and a second table of the same shape,
 * `label.behind`, the masked ones — the stage draws it before the sprites,
 * the first one after (the arcade's per cell priority, r-type stages 7-8).
 * A dense column keeps a fixed layout in `label` : it may hold no masked
 * cell. Without `behind` the output is unchanged.
 */
@Slf4j
public class TilecolsPlugin {

	public static File getFile(ImmutableNode node, BuildContext ctx) throws Exception {

		String map = ctx.path + File.separator + Attribute.getString(node, ctx, "map");
		String label = Attribute.getString(node, ctx, "label");
		String tiles = Attribute.getString(node, ctx, "tiles");
		String variant = Attribute.getString(node, ctx, "variant");
		String gensource = ctx.path + File.separator + Attribute.getString(node, ctx, "gensource");
		int rows = Attribute.getInteger(node, ctx, "maprows");
		int rowstep = Attribute.getInteger(node, ctx, "rowstep", 480);
		String dense = Attribute.getString(node, ctx, "dense", "");
		String nullTile = Attribute.getString(node, ctx, "nulltile", "tilemap.null");
		String section = Attribute.getString(node, ctx, "section", "map");
		int bitdepth = Attribute.getInteger(node, ctx, "bitdepth", 16);
		String behindPath = Attribute.getString(node, ctx, "behind", "");

		if (bitdepth != 8 && bitdepth != 16) {
			throw new Exception("tilecols " + label + " : bitdepth must be 8 or 16");
		}
		if (rows <= 0 || rows > 16) {
			throw new Exception("tilecols " + label + " : maprows must be 1..16");
		}

		byte[] data = Files.readAllBytes(Paths.get(map));
		int step = bitdepth / 8;
		if (data.length % (step * rows) != 0) {
			throw new Exception("tilecols " + label + " : " + map + " is " + data.length
					+ " bytes, not a whole number of columns of " + rows + " indexes of " + bitdepth + " bits");
		}
		int entries = data.length / step;
		int cols = entries / rows;

		int[] ids = new int[entries];
		TreeSet<Integer> used = new TreeSet<Integer>();
		for (int i = 0; i < entries; i++) {
			ids[i] = step == 1 ? data[i] & 0xFF
					: ((data[i * 2] & 0xFF) << 8) | (data[i * 2 + 1] & 0xFF);
			if (ids[i] != 0) {
				used.add(ids[i]);
			}
		}

		// the dense columns : "4-5,10" — those an animation rewrites
		boolean[] isDense = new boolean[cols];
		if (!dense.isBlank()) {
			for (String range : dense.split(",")) {
				String r = range.trim();
				int a, b;
				int dash = r.indexOf('-');
				if (dash > 0) {
					a = Integer.parseInt(r.substring(0, dash).trim());
					b = Integer.parseInt(r.substring(dash + 1).trim());
				} else {
					a = b = Integer.parseInt(r);
				}
				if (a < 0 || b >= cols || a > b) {
					throw new Exception("tilecols " + label + " : dense range " + r + " outside the map's " + cols + " columns");
				}
				for (int c = a; c <= b; c++) {
					isDense[c] = true;
				}
			}
		}

		byte[] behind = null;
		if (!behindPath.isBlank()) {
			String file = ctx.path + File.separator + behindPath;
			behind = Files.readAllBytes(Paths.get(file));
			if (behind.length != entries) {
				throw new Exception("tilecols " + label + " : behind mask " + file + " is " + behind.length
						+ " bytes, the map has " + entries + " cells");
			}
		}

		com.widedot.m6809.gamebuilder.spi.globals.Machines.Machine machine =
				ctx.machines.required("<tilecols>");
		StringBuilder source = new StringBuilder();
		source.append("* Generated by tilecols from ").append(map).append(System.lineSeparator());
		source.append("* ").append(cols).append(" columns of ").append(rows).append(" rows,")
				.append(" tiles ").append(tiles).append(" variant ").append(variant)
				.append(", row step ").append(rowstep).append(System.lineSeparator());
		source.append("        INCLUDE \"").append(machine.pageInclude).append('"')
				.append(System.lineSeparator());
		for (int id : used) {
			String tile = "adr_" + tiles + "_" + id + "_" + variant;
			source.append(tile).append(" EXTERNAL").append(System.lineSeparator());
			source.append(tile).append("$PAGE EXTERNAL").append(System.lineSeparator());
		}
		// the null tile of a dense column : resident, or in the unit that
		// holds the table — either way one provider, baked like the rest
		boolean anyDense = false;
		for (boolean d : isDense) {
			anyDense |= d;
		}
		if (anyDense) {
			source.append(nullTile).append(" EXTERNAL").append(System.lineSeparator());
		}
		// the page byte of a null cell : any existing page will do (the null
		// tile is resident) — the page of the first tile used keeps every
		// entry's page a real one
		String anyPage = used.isEmpty() ? "1" : machine.pageExpr + "adr_" + tiles + "_" + used.first() + "_" + variant + "$PAGE";

		int[] stats = new int[3];
		columns(source, label, ids, cols, rows, isDense, behind, false, tiles, variant,
				machine.pageExpr, anyPage, nullTile, rowstep, section, stats);
		if (behind != null) {
			columns(source, label + ".behind", ids, cols, rows, isDense, behind, true, tiles, variant,
					machine.pageExpr, anyPage, nullTile, rowstep, section, stats);
		}
		int full = stats[0], nulls = stats[1], bytes = stats[2];

		Path path = Paths.get(gensource);
		if (path.getParent() != null) {
			Files.createDirectories(path.getParent());
		}
		Files.writeString(path, source.toString());
		log.info("tilecols {} : {} columns, {} full cells, {} null cells of dense columns, {} bytes at run time (dense table : {})",
				label, cols, full, nulls, bytes, entries * 3);
		return path.toFile();
	}

	/**
	 * One column table : the word per column, then each column's list. With a
	 * mask, `back` selects the masked cells (the behind table, never dense) or
	 * the others. stats : full cells, null cells, bytes — accumulated.
	 */
	static void columns(StringBuilder source, String label, int[] ids, int cols, int rows,
			boolean[] isDense, byte[] behind, boolean back, String tiles, String variant,
			String pageExpr, String anyPage, String nullTile, int rowstep, String section,
			int[] stats) throws Exception {
		String nl = System.lineSeparator();
		source.append(label).append(" EXPORT").append(nl);
		source.append(" SECTION ").append(section).append(nl);
		source.append(label).append(nl);
		for (int c = 0; c < cols; c++) {
			source.append("        fdb   ").append(label).append(".c").append(c).append(nl);
		}
		stats[2] += cols * 2;
		for (int c = 0; c < cols; c++) {
			boolean dense = isDense[c] && !back;
			source.append(label).append(".c").append(c).append(nl);
			for (int r = 0; r < rows; r++) {
				int id = ids[c * rows + r];
				boolean masked = behind != null && id != 0 && behind[c * rows + r] != 0;
				if (masked && isDense[c]) {
					throw new Exception("tilecols " + label + " : column " + c
							+ " is dense and has a cell behind the sprites (row " + r + ")");
				}
				if (id != 0 && masked != back) {
					id = 0;                // the other table's cell
				}
				if (id == 0 && !dense) {
					continue;
				}
				if (id == 0) {
					source.append("        fcb   ").append(anyPage).append(nl);
					source.append("        fdb   ").append(nullTile).append(nl);
					stats[1]++;
				} else {
					String symbol = "adr_" + tiles + "_" + id + "_" + variant;
					source.append("        fcb   ").append(pageExpr).append(symbol)
							.append("$PAGE").append(nl);
					source.append("        fdb   ").append(symbol).append(nl);
					stats[0]++;
				}
				source.append("        fdb   ").append(r * rowstep).append(nl);
				stats[2] += 5;
			}
			source.append("        fcb   0").append(nl);
			stats[2] += 1;
		}
		source.append(" ENDSECTION").append(nl);
	}
}
