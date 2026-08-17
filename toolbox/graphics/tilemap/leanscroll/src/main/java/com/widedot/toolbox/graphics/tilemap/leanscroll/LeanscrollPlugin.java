package com.widedot.toolbox.graphics.tilemap.leanscroll;

import java.awt.image.BufferedImage;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;

import javax.imageio.ImageIO;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;

import lombok.extern.slf4j.Slf4j;

/**
 * Handler for the {@code <leanscroll>} element : the level-map chain, run by
 * the build instead of by hand (7c).
 *
 * From one level picture ({@code image=}) the module derives the two scroll
 * planes — the odd one pre-shifted by a pixel, which is what makes the
 * engine's 1 px scroll free — each as a tileset strip plus a column-major
 * 16 bit map. The plugin then windows and renumbers them exactly as
 * tools/crop_stage.py used to : the kept window's tiles are renumbered
 * consecutively (id 0 stays 0, the "draw nothing" convention), the strip
 * keeps the source's empty tile at position 0, and the geometry comes out
 * as equates ({@code gensymbols=}) instead of a hand-run script's output.
 *
 * Everything lands under {@code gendir=} : {@code even.png / even.bin /
 * odd.png / odd.bin} are what a {@code <gfxcomp grid>} and a
 * {@code <tilemap>} consume. The intermediates live in {@code 0/} and
 * {@code 1/} beside them. Results are cached on the image bytes and the
 * parameters — the chain runs once per art change, not once per build pass.
 */
@Slf4j
public class LeanscrollPlugin {

	private static final String CACHE_VERSION = "3";


	public static void run(ImmutableNode node, BuildContext ctx) throws Exception {

		String image = Attribute.getString(node, ctx, "image");
		String gendir = Attribute.getString(node, ctx, "gendir");
		String tile = Attribute.getString(node, ctx, "tile", "12x12");
		Integer columns = Attribute.getIntegerOpt(node, ctx, "columns");
		int first = Attribute.getInteger(node, ctx, "first", 0);
		String gensymbols = Attribute.getStringOpt(node, ctx, "gensymbols");
		// the engine's dual-plane 1 px horizontal scroll : plane 1 is the
		// pre-shifted copy, 4 sub-steps — override for another scroll model
		String scrollstep = Attribute.getString(node, ctx, "scrollstep", "0,0,1,0,0,0,0,0");
		String nbsteps = Attribute.getString(node, ctx, "nbsteps", "0,0,4,0,0,0,0,0");
		String refresh = Attribute.getStringOpt(node, ctx, "refresh");

		String[] dims = tile.split("x");
		if (dims.length != 2) {
			throw new Exception("<leanscroll> tile must be <width>x<height>, got '" + tile + "'");
		}
		int tileW = Integer.parseInt(dims[0]);
		int tileH = Integer.parseInt(dims[1]);

		Path in = Paths.get(ctx.path, image);
		if (!Files.isRegularFile(in)) {
			throw new Exception(ctx.sources.locate(node) + ": <leanscroll> image '" + image
					+ "' does not exist");
		}
		Path out = Paths.get(ctx.path, gendir);
		Files.createDirectories(out);

		// the geometry comes from the level picture itself : its height in
		// tiles is the map's row count, its width the level's column count
		BufferedImage level = ImageIO.read(in.toFile());
		int rows = level.getHeight() / tileH;
		int totalCols = level.getWidth() / tileW;
		int cols = columns != null ? columns : totalCols;
		if (first + cols > totalCols) {
			throw new Exception(ctx.sources.locate(node) + ": <leanscroll> window : "
					+ totalCols + " columns only, asked " + first + ".." + (first + cols - 1));
		}

		// the refresh cells, DECLARED : the buffered scroll never repaints a
		// zero cell — that is the lean's point — but a checkpoint restart
		// repaints the playfield from the map, so a band the scroll cannot
		// rebuild from its start-of-stage blocks must stay a DRAWN cell.
		// This is authored data the level picture cannot carry (v1 held it
		// as a hand edit of the generated map, lost on regeneration) ; see
		// docs/lang/en/migration/checkpoint-refresh-cells.md
		java.util.Set<Integer> forced = new java.util.HashSet<>();
		if (refresh != null) {
			for (String part : refresh.trim().split("[,\\s]+")) {
				String[] cr = part.split(":");
				if (cr.length != 2) {
					throw new Exception(ctx.sources.locate(node) + ": <leanscroll> refresh"
							+ " entry '" + part + "' — expected <col>:<row> or"
							+ " <col>:<rowFirst>-<rowLast>");
				}
				int col = Integer.parseInt(cr[0]);
				String[] span = cr[1].split("-");
				int r0 = Integer.parseInt(span[0]);
				int r1 = span.length > 1 ? Integer.parseInt(span[1]) : r0;
				for (int r = r0; r <= r1; r++) {
					forced.add(col * rows + r);
				}
			}
		}

		com.widedot.m6809.gamebuilder.spi.cache.BuildCache.Entry entry =
				com.widedot.m6809.gamebuilder.spi.cache.BuildCache.entry("leanscroll", CACHE_VERSION)
						.keyString(tile + "|" + columns + "|" + first + "|" + scrollstep
								+ "|" + nbsteps + "|" + refresh)
						.keyBytes(Files.readAllBytes(in));
		Path cached = entry.find();
		String[] finals = { "even.png", "even.bin", "odd.png", "odd.bin" };
		if (cached != null) {
			for (String f : finals) {
				Files.copy(cached.resolve(f), out.resolve(f),
						java.nio.file.StandardCopyOption.REPLACE_EXISTING);
			}
		} else {
			// stage 1 : the module, in this JVM — the invocation the recipe
			// files used to carry (leanscroll-06.txt documents it verified)
			for (String plane : new String[] { "0", "1" }) {
				Files.createDirectories(out.resolve(plane));
			}
			int code = new picocli.CommandLine(new MainCommand()).execute(
					"-image=" + in,
					"-outtileset=" + out.resolve("0/0.png"),
					"-outtilemap=" + out.resolve("0/0.bin"),
					"-outtileset1=" + out.resolve("1/1.png"),
					"-outtilemap1=" + out.resolve("1/1.bin"),
					"-scrollstep=" + scrollstep,
					"-nbsteps=" + nbsteps,
					"-outtilewidth=" + tileW,
					"-outtileheight=" + tileH,
					"-outmapbitdepth=16",
					"-outmaptranspose");
			if (code != 0) {
				throw new Exception("<leanscroll> failed on '" + image + "' (exit " + code + ")");
			}

			// stage 2 : the window, renumbered — crop_stage.py, absorbed
			window(out.resolve("0"), "0", out, "even", tileW, tileH, rows, cols, first, forced);
			window(out.resolve("1"), "1", out, "odd", tileW, tileH, rows, cols, first, forced);

			entry.store(staging -> {
				for (String f : finals) {
					Files.copy(out.resolve(f), staging.resolve(f));
				}
			});
		}

		if (gensymbols != null) {
			Path sym = Paths.get(ctx.path, gensymbols);
			Files.createDirectories(sym.getParent());
			Files.write(sym, (
					"* ===========================================================================\n"
					+ "* Geometrie de la section — genere par <leanscroll>\n"
					+ "* ===========================================================================\n"
					+ "map.COLS  equ " + cols + "\n"
					+ "map.ROWS  equ " + rows + "\n")
					.getBytes(StandardCharsets.UTF_8));
		}
		log.info("leanscroll {} : planes and window under {}", image, gendir);
	}

	/**
	 * The window : keep {@code columns} columns from {@code first}, renumber
	 * the used tiles consecutively (0 stays 0), write the strip and the
	 * column-major 16 bit map. The strip's position 0 is the source tileset's
	 * own empty tile, kept so the sheet stays readable against its source.
	 * A {@code forced} cell the module left empty is bound to tile 1 — the
	 * set's first tile — so the scroll keeps repainting it (the declared
	 * checkpoint refresh contract, {@code refresh=}).
	 */
	private static void window(Path planeDir, String plane, Path out, String name,
			int tileW, int tileH, int rows, int cols, int first,
			java.util.Set<Integer> forced) throws Exception {

		// the module suffixes each scroll step's map ; step 0 is the resting
		// map the engine's buffered scroll consumes
		byte[] raw = Files.readAllBytes(planeDir.resolve(plane + ".0.bin"));
		BufferedImage sheet = ImageIO.read(planeDir.resolve(plane + ".png").toFile());
		// leanscroll writes the map transposed : ids run column-major
		List<Integer> ids = new ArrayList<>();
		for (int i = 0; i + 1 < raw.length; i += 2) {
			ids.add(((raw[i] & 0xFF) << 8) | (raw[i + 1] & 0xFF));
		}
		List<Integer> kept = new ArrayList<>();
		for (int c = first; c < first + cols; c++) {
			for (int r = 0; r < rows; r++) {
				kept.add(ids.get(c * rows + r));
			}
		}
		TreeSet<Integer> used = new TreeSet<>(kept);
		used.remove(0);
		Map<Integer, Integer> renum = new LinkedHashMap<>();
		int n = 1;
		for (int old : used) {
			renum.put(old, n++);
		}

		// raw raster copy, never drawImage : drawing into an indexed image
		// remaps colours by proximity, which silently merges palette entries
		// (the two magentas) and shifts every pixel index
		BufferedImage strip = new BufferedImage(tileW, tileH * (used.size() + 1),
				BufferedImage.TYPE_BYTE_INDEXED,
				(java.awt.image.IndexColorModel) sheet.getColorModel());
		java.awt.image.Raster src = sheet.getRaster();
		java.awt.image.WritableRaster dst = strip.getRaster();
		dst.setRect(0, 0, src.createChild(0, 0, tileW, tileH, 0, 0, null));
		int at = 1;
		for (int old : used) {
			dst.setRect(0, at++ * tileH,
					src.createChild(0, old * tileH, tileW, tileH, 0, 0, null));
		}
		ImageIO.write(strip, "png", out.resolve(name + ".png").toFile());

		byte[] bin = new byte[kept.size() * 2];
		for (int i = 0; i < kept.size(); i++) {
			int v = renum.getOrDefault(kept.get(i), 0);
			if (v == 0 && forced.contains((first + i / rows) * rows + i % rows)) {
				v = 1;
			}
			bin[i * 2] = (byte) (v >> 8);
			bin[i * 2 + 1] = (byte) v;
		}
		Files.write(out.resolve(name + ".bin"), bin);
		log.info("leanscroll {} : columns {}..{}, {} tiles used", name, first,
				first + cols - 1, used.size());
		census(name, strip, tileW, tileH, bin);
	}

	/**
	 * What the tileset is MADE OF, logged per plane.
	 *
	 * Two numbers per class, and they answer different questions : distinct
	 * tiles is what the class costs in SPACE (a tile is compiled once),
	 * placements is what it costs in CYCLES (a tile is played once per cell
	 * that names it). A class can be cheap in one and dear in the other.
	 *
	 * The classes split on index 1 — hardware colour 0, the black that the
	 * level map is now overwhelmingly made of since the sky joined it :
	 *
	 *   EMPTY    no opaque pixel. The map addresses it as id 0 and the scroll
	 *            skips it, so it is free in both space and cycles.
	 *   BLACK    transparent and black only. The candidate for a cheaper path
	 *            than a compiled routine — measure before believing it.
	 *   MIXED    black AND colour.
	 *   COLOUR   no black at all.
	 *
	 * Measured on r-type stage 1 (17/08/2026) : EMPTY covers 74 % of the
	 * cells, BLACK weighs 5.7 % of the compiled bytes and 7.8 % of the
	 * cycles, MIXED carries all the rest. The compiled sizes and the cycle
	 * counts are NOT known here — they only exist after gfxcomp — and live in
	 * games/r-type/tools/tile_stats.py, which crosses this census with the
	 * generated 6809 code.
	 */
	private static void census(String name, BufferedImage strip, int tileW, int tileH,
			byte[] bin) {
		int n = strip.getHeight() / tileH;
		java.awt.image.Raster r = strip.getRaster();
		String[] cls = new String[n];
		for (int t = 0; t < n; t++) {
			boolean black = false, colour = false;
			for (int y = 0; y < tileH; y++) {
				for (int x = 0; x < tileW; x++) {
					int v = r.getSample(x, t * tileH + y, 0);
					if (v == 1) {
						black = true;
					} else if (v != 0) {
						colour = true;
					}
				}
			}
			cls[t] = !black && !colour ? "EMPTY"
					: colour ? (black ? "MIXED" : "COLOUR") : "BLACK";
		}
		Map<String, int[]> tally = new LinkedHashMap<>();
		for (String k : new String[] { "EMPTY", "BLACK", "MIXED", "COLOUR" }) {
			tally.put(k, new int[2]);
		}
		for (int t = 0; t < n; t++) {
			tally.get(cls[t])[0]++;
		}
		for (int i = 0; i + 1 < bin.length; i += 2) {
			int id = ((bin[i] & 0xFF) << 8) | (bin[i + 1] & 0xFF);
			if (id < n) {
				tally.get(cls[id])[1]++;
			}
		}
		StringBuilder sb = new StringBuilder();
		for (Map.Entry<String, int[]> e : tally.entrySet()) {
			if (e.getValue()[0] == 0 && e.getValue()[1] == 0) {
				continue;
			}
			sb.append(sb.length() == 0 ? "" : ", ").append(e.getKey()).append(' ')
			  .append(e.getValue()[0]).append(" tiles/").append(e.getValue()[1])
			  .append(" placed");
		}
		log.info("leanscroll {} : {}", name, sb);
	}
}
