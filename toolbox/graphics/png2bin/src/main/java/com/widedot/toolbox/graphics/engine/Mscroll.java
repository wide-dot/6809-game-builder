package com.widedot.toolbox.graphics.engine;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.widedot.toolbox.graphics.png.Png;

import lombok.extern.slf4j.Slf4j;

/**
 * Builds the assets of the mscroll engine module (multidirectional scroll,
 * engine/graphics/tilemap/mscroll/) from ONE indexed PNG holding the whole
 * map. See docs/lang/fr/etude-mscroll-2026-08.md.
 *
 * The data layout is the one the runtime reads fastest :
 *
 *  - tiles are 8x16, stored TILE-MAJOR : the 16 lines of a tile are
 *    consecutive words, 32 bytes per tile and per plane, 512 tiles max.
 *    The 16KB plane file has its 8KB halves swapped, so that the $A000-$DFFF
 *    data window (whose halves are physically inverted) shows it linear ;
 *  - the map holds 16-bit tile ids PREMULTIPLIED BY 32 (the tile stride),
 *    row-major, and the row stride is padded to a POWER OF TWO so a row
 *    address is a shift — the shift is published in the generated .equ ;
 *  - the start buffers are the initial view at camera (0,0) as pshs chunks
 *    (ldd # / ldx # / pshs d,x per 16px), in reverse order, one per plane.
 *    The including unit appends the extra buffer line and the wrap jmp.
 *
 * Colour convention : the shiftColors flag of png2bin — PNG index 0 is
 * unused, indexes 1..16 are hardware colours 0..15.
 */
@Slf4j
public class Mscroll {

	public static final int TILE_W = 8;
	public static final int TILE_H = 16;
	public static final int MAX_TILES = 512;
	public static final int VIEW_W = 160;

	public final int width;
	public final int height;
	public final int cols;
	public final int rows;
	public final int stride;      // map row stride in bytes, a power of two
	public final int rowshift;    // log2(stride)

	private final int[] pix;      // hardware values, width*height
	private final List<byte[]> tiles = new ArrayList<byte[]>();
	private final int[][] grid;
	private final Map<String, Integer> seen = new HashMap<String, Integer>();

	/** One PATCH of the map : the cells of one rectangle of the patch image
	 *  whose tile differs from the map's, with the ids of both. The runtime
	 *  writes the patch ids into the map (and re-feeds the columns in the
	 *  window) when the patch is applied, the original ids to undo it. */
	public static final class Patch {
		public final String name;
		public int col0 = Integer.MAX_VALUE, col1 = -1;
		public final List<int[]> cells = new ArrayList<int[]>(); // {offset, origId, patchId}
		Patch(String name) { this.name = name; }
	}
	private final List<Patch> patches = new ArrayList<Patch>();
	/** cells one patch may carry : the runtime copies a patch into a fixed
	 *  buffer of this many entries before mounting the map page */
	public static final int PATCH_MAX_CELLS = 12;

	public Mscroll(File pngFile, boolean shiftColors) throws Exception {
		this(pngFile, shiftColors, null, null);
	}

	/**
	 * @param patchImage same size as the map, the map with every patch
	 *        painted in place — or null
	 * @param patchCsv   the patch rectangles : a header line, then
	 *        {@code name,x,y,w,h} in pixels of the map — or null
	 */
	public Mscroll(File pngFile, boolean shiftColors, File patchImage, File patchCsv) throws Exception {

		Png png = new Png(pngFile);
		width = png.width;
		height = png.height;
		if (width % TILE_W != 0 || height % TILE_H != 0) {
			throw new Exception("mscroll : " + pngFile.getName() + " is " + width + "x" + height
			                  + ", the map must be a whole number of 8x16 tiles");
		}
		if (width < VIEW_W) {
			throw new Exception("mscroll : the map must be at least " + VIEW_W + " pixels wide");
		}
		cols = width / TILE_W;
		rows = height / TILE_H;

		int s = 1;
		while (s < cols * 2) s <<= 1;
		stride = s;
		int sh = 0;
		while ((1 << sh) < stride) sh++;
		rowshift = sh;
		if (rows * stride > 16384) {
			throw new Exception("mscroll : the map does not fit a 16KB page ("
			                  + rows + " rows of " + stride + " bytes)");
		}

		// unpack the indexed pixels to hardware values
		pix = unpack(png, shiftColors);

		// cut and deduplicate the tiles
		grid = new int[rows][cols];
		for (int r = 0; r < rows; r++) {
			for (int c = 0; c < cols; c++) {
				grid[r][c] = tileId(pix, r, c);
			}
		}
		int base = tiles.size();
		log.info("mscroll {} : {}x{} tiles, {} unique, row stride {} (shift {})",
		         pngFile.getName(), cols, rows, tiles.size(), stride, rowshift);

		// the patches : their tiles join the set (deduplicated against it and
		// against each other), the map keeps the original ids
		if (patchImage != null || patchCsv != null) {
			if (patchImage == null || patchCsv == null) {
				throw new Exception("mscroll : patches and patchimage go together");
			}
			Png ppng = new Png(patchImage);
			if (ppng.width != width || ppng.height != height) {
				throw new Exception("mscroll : " + patchImage.getName() + " is " + ppng.width + "x"
				                  + ppng.height + ", the patch image must be the map's size");
			}
			int[] ppix = unpack(ppng, shiftColors);
			List<String> lines = java.nio.file.Files.readAllLines(patchCsv.toPath());
			for (int i = 1; i < lines.size(); i++) {
				String line = lines.get(i).trim();
				if (line.isEmpty()) continue;
				String[] f = line.split(",");
				if (f.length < 5) {
					throw new Exception("mscroll : " + patchCsv.getName() + " line " + (i + 1)
					                  + " : expected name,x,y,w,h");
				}
				Patch p = new Patch(f[0].trim());
				int x = Integer.parseInt(f[1].trim()), y = Integer.parseInt(f[2].trim());
				int w = Integer.parseInt(f[3].trim()), h = Integer.parseInt(f[4].trim());
				if (x < 0 || y < 0 || w <= 0 || h <= 0 || x + w > width || y + h > height) {
					throw new Exception("mscroll : patch " + p.name + " is outside the map");
				}
				for (int c = x / TILE_W; c <= (x + w - 1) / TILE_W; c++) {
					for (int r = y / TILE_H; r <= (y + h - 1) / TILE_H; r++) {
						int id = tileId(ppix, r, c);
						if (id == grid[r][c]) continue;
						p.cells.add(new int[] { r * stride + c * 2, grid[r][c], id });
						p.col0 = Math.min(p.col0, c);
						p.col1 = Math.max(p.col1, c);
					}
				}
				if (p.cells.size() > PATCH_MAX_CELLS) {
					throw new Exception("mscroll : patch " + p.name + " changes " + p.cells.size()
					                  + " cells, the runtime buffer holds " + PATCH_MAX_CELLS);
				}
				patches.add(p);
			}
			log.info("mscroll {} : {} patches, {} new tiles ({} in the set)",
			         patchImage.getName(), patches.size(), tiles.size() - base, tiles.size());
		}
		if (tiles.size() > MAX_TILES) {
			throw new Exception("mscroll : " + tiles.size() + " unique tiles, the tileset holds "
			                  + MAX_TILES + " at most");
		}
	}

	private int[] unpack(Png png, boolean shiftColors) throws Exception {
		int[] out = new int[width * height];
		int bits = png.colorModel.getPixelSize();
		for (int y = 0; y < height; y++) {
			for (int x = 0; x < width; x++) {
				int idx;
				if (bits == 8) {
					idx = png.dataBuffer.getElem(y * width + x);
				} else if (bits == 4) {
					int b = png.dataBuffer.getElem((y * width + x) / 2);
					idx = (x % 2 == 0) ? (b >> 4) & 0x0F : b & 0x0F;
				} else {
					throw new Exception("mscroll : unsupported pixel depth " + bits);
				}
				out[y * width + x] = shiftColors && idx != 0 ? (idx - 1) & 0x0F : idx & 0x0F;
			}
		}
		return out;
	}

	/** the id of the tile at (r, c) of a pixel array, added to the set if new */
	private int tileId(int[] p, int r, int c) {
		byte[] t = new byte[TILE_W * TILE_H];
		for (int l = 0; l < TILE_H; l++) {
			for (int i = 0; i < TILE_W; i++) {
				t[l * TILE_W + i] = (byte) p[(r * TILE_H + l) * width + c * TILE_W + i];
			}
		}
		String key = java.util.Arrays.toString(t);
		Integer id = seen.get(key);
		if (id == null) {
			id = tiles.size();
			tiles.add(t);
			seen.put(key, id);
		}
		return id;
	}

	public boolean hasPatches() {
		return !patches.isEmpty();
	}

	/**
	 * The patch tables, as an asm source the game includes : an index of
	 * pointers, then per patch {@code fcb cells, col0, cols} and per cell
	 * {@code fdb offset, originalId, patchId} — offsets in bytes into the
	 * map, ids premultiplied by 32 as the map holds them.
	 */
	public String patchesAsm(String symbol) {
		StringBuilder sb = new StringBuilder();
		sb.append("; GENERE par l'element <mscroll patches=...> : les patches de la carte ")
		  .append(symbol).append('\n');
		sb.append("; index : fdb par patch ; patch : fcb cellules, colonne 0, colonnes ;\n");
		sb.append("; cellule : fdb offset (octets dans la carte), id d'origine, id du patch\n");
		sb.append("; (ids x32, tels que la carte les porte). ").append(symbol)
		  .append(".PATCHES dans le .equ.\n");
		sb.append(symbol).append(".patches\n");
		for (int i = 0; i < patches.size(); i++) {
			sb.append("        fdb   ").append(symbol).append(".patch.").append(i).append('\n');
		}
		for (int i = 0; i < patches.size(); i++) {
			Patch p = patches.get(i);
			int cols = p.cells.isEmpty() ? 0 : p.col1 - p.col0 + 1;
			sb.append(symbol).append(".patch.").append(i).append("   ; ").append(p.name).append('\n');
			sb.append("        fcb   ").append(p.cells.size()).append(',')
			  .append(p.cells.isEmpty() ? 0 : p.col0).append(',').append(cols).append('\n');
			for (int[] cell : p.cells) {
				sb.append(String.format("        fdb   $%04X,$%04X,$%04X%n",
				                        cell[0], cell[1] * 32, cell[2] * 32));
			}
		}
		return sb.toString();
	}

	/** the two plane bytes of one tile line : plane 0 gets pixels 0,1 and 4,5 */
	private byte[] tileLine(byte[] t, int l, int plane) {
		int o = l * TILE_W + (plane == 0 ? 0 : 2);
		return new byte[] { (byte) ((t[o] << 4) | t[o + 1]),
		                    (byte) ((t[o + 4] << 4) | t[o + 5]) };
	}

	/** tile-major plane file : 16KB, 8KB halves swapped for the data window */
	/** Tile-major tileset for one plane. The data window maps the page
	 *  halves physically inverted, so tile 0 (runtime $A000) lives at page
	 *  offset $2000. Up to 256 tiles the file only covers the used bytes and
	 *  MUST be loaded at page offset $2000 ; past 256 tiles it is the full
	 *  16K page with the two halves swapped, loaded at offset $0000. */
	public byte[] tiles(int plane) {
		byte[] out = new byte[16384];
		int k = 0;
		for (byte[] t : tiles) {
			for (int l = 0; l < TILE_H; l++) {
				byte[] w = tileLine(t, l, plane);
				out[k++] = w[0];
				out[k++] = w[1];
			}
		}
		if (tiles.size() <= 256) {
			byte[] half = new byte[tiles.size() * 32];
			System.arraycopy(out, 0, half, 0, half.length);
			return half;
		}
		byte[] swapped = new byte[16384];
		System.arraycopy(out, 8192, swapped, 0, 8192);
		System.arraycopy(out, 0, swapped, 8192, 8192);
		return swapped;
	}

	/** rows of 16-bit ids premultiplied by 32, padded to the row stride */
	public byte[] map() {
		byte[] out = new byte[rows * stride];
		for (int r = 0; r < rows; r++) {
			for (int c = 0; c < cols; c++) {
				int v = grid[r][c] * 32;
				out[r * stride + c * 2] = (byte) (v >> 8);
				out[r * stride + c * 2 + 1] = (byte) v;
			}
		}
		return out;
	}

	/** the initial view at camera (0,0) as a reverse chunk stream, one plane.
	 *  Emits viewHeight+1 lines (y 0..viewHeight) : the cycling buffer is one
	 *  line taller than the view so the patched exit jmp always has room, and
	 *  that extra line pairs with map line y=viewHeight at boot — leaving it
	 *  blank would scroll a hole across the screen for the first buffer cycle. */
	public byte[] start(int plane, int viewHeight) throws Exception {
		if (viewHeight + 1 > height) {
			throw new Exception("mscroll : the start view needs " + (viewHeight + 1)
			                  + " lines, the map only has " + height);
		}
		byte[] raw = new byte[(viewHeight + 1) * 40];
		int k = 0;
		for (int y = 0; y < viewHeight + 1; y++) {
			for (int x = 0; x < VIEW_W; x += 4) {
				int a = plane == 0 ? x : x + 2;
				// map-fixed seam shear : columns beyond each 160px seam are
				// written one line up per seam, exactly like the runtime
				// feeds do (see engine mscroll.asm, the note in mscroll.move)
				int ys = ((y - a / 160) % height + height) % height;
				raw[k++] = (byte) ((pix[ys * width + a] << 4) | pix[ys * width + a + 1]);
			}
		}
		byte[] out = new byte[(raw.length / 4) * 8];
		int o = 0;
		for (int i = raw.length - 4; i >= 0; i -= 4) {
			out[o++] = (byte) 0xCC; out[o++] = raw[i];     out[o++] = raw[i + 1];
			out[o++] = (byte) 0x8E; out[o++] = raw[i + 2]; out[o++] = raw[i + 3];
			out[o++] = 0x34;        out[o++] = 0x16;       // pshs d,x
		}
		return out;
	}

	/** the geometry, for the game mode's _mscroll.set* calls */
	public String equ(String symbol) {
		StringBuilder sb = new StringBuilder();
		sb.append(symbol).append(".MAP_WIDTH  equ ").append(width).append('\n');
		sb.append(symbol).append(".MAP_HEIGHT equ ").append(height).append('\n');
		sb.append(symbol).append(".ROWSHIFT   equ ").append(rowshift).append('\n');
		sb.append(symbol).append(".TILES      equ ").append(tiles.size()).append('\n');
		sb.append(symbol).append(".PATCHES    equ ").append(patches.size()).append('\n');
		return sb.toString();
	}
}
