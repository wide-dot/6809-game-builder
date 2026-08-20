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

	public Mscroll(File pngFile, boolean shiftColors) throws Exception {

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
		pix = new int[width * height];
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
				pix[y * width + x] = shiftColors && idx != 0 ? (idx - 1) & 0x0F : idx & 0x0F;
			}
		}

		// cut and deduplicate the tiles
		Map<String, Integer> seen = new HashMap<String, Integer>();
		grid = new int[rows][cols];
		for (int r = 0; r < rows; r++) {
			for (int c = 0; c < cols; c++) {
				byte[] t = new byte[TILE_W * TILE_H];
				for (int l = 0; l < TILE_H; l++) {
					for (int i = 0; i < TILE_W; i++) {
						t[l * TILE_W + i] = (byte) pix[(r * TILE_H + l) * width + c * TILE_W + i];
					}
				}
				String key = java.util.Arrays.toString(t);
				Integer id = seen.get(key);
				if (id == null) {
					id = tiles.size();
					tiles.add(t);
					seen.put(key, id);
				}
				grid[r][c] = id;
			}
		}
		if (tiles.size() > MAX_TILES) {
			throw new Exception("mscroll : " + tiles.size() + " unique tiles, the tileset holds "
			                  + MAX_TILES + " at most");
		}
		log.info("mscroll {} : {}x{} tiles, {} unique, row stride {} (shift {})",
		         pngFile.getName(), cols, rows, tiles.size(), stride, rowshift);
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
		return sb.toString();
	}
}
