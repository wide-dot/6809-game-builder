package com.widedot.toolbox.graphics.raycast;

import java.util.ArrayList;
import java.util.List;

/**
 * The compiled wall scalers : one routine a height, drawing a texture column
 * scaled to that height in a byte column of the screen.
 *
 * In : X the texture column (64 texels, a byte each), U the column's row 0.
 * A routine writes the wall's rows only (a wall taller than the view is
 * clipped) : ceiling and floor stay in the buffer. A texel is loaded once
 * for its run of rows ; two runs of consecutive texels share an ldd (6
 * cycles instead of 2 x 5) ; each row is one sta/stb n,u, U moved every 7
 * rows so the offsets keep 8 bits.
 */
final class ScalerGen {

	/** a routine : its height in rows, its source lines, its size in bytes */
	static final class Routine {
		final int height;
		final List<String> lines;
		final int size;

		Routine(int height, List<String> lines, int size) {
			this.height = height;
			this.lines = lines;
			this.size = size;
		}
	}

	private final Geometry g;

	ScalerGen(Geometry g) {
		this.g = g;
	}

	/**
	 * bytes of an indexed instruction with a constant offset (lwasm picks the
	 * shortest : none, 5 bits, 8 bits, 16 bits)
	 */
	static int indexedSize(int off) {
		if (off >= -16 && off <= 15) {
			return 2;
		}
		if (off >= -128 && off <= 127) {
			return 3;
		}
		return 4;
	}

	/** the routine of the walls h rows high */
	Routine routine(int h) {
		int t = g.topRow(h);
		int[] texel = g.texelRows(h);
		int y0 = Math.max(0, t);
		int y1 = Math.min(g.rows, t + h);
		List<int[]> runs = new ArrayList<int[]>();           // texel, rows
		for (int y = y0; y < y1; y++) {
			int tx = texel[y - t];
			if (!runs.isEmpty() && runs.get(runs.size() - 1)[0] == tx) {
				runs.get(runs.size() - 1)[1]++;
			} else {
				runs.add(new int[] { tx, 1 });
			}
		}
		// which register holds each run, and where the loads go
		String[] load = new String[runs.size()];
		char[] reg = new char[runs.size()];
		for (int i = 0; i < runs.size();) {
			int tx = runs.get(i)[0];
			if (i + 1 < runs.size() && runs.get(i + 1)[0] == tx + 1) {
				load[i] = "ldd";
				reg[i] = 'a';
				reg[i + 1] = 'b';
				i += 2;
			} else {
				load[i] = "lda";
				reg[i] = 'a';
				i++;
			}
		}
		List<String> lines = new ArrayList<String>();
		int first = (y0 + Geometry.BIAS) * Geometry.STRIDE;
		lines.add("        leau  " + first + ",u");
		int size = indexedSize(first);
		int base = y0 + Geometry.BIAS;                         // the screen row U points at
		int y = y0;
		for (int i = 0; i < runs.size(); i++) {
			int tx = runs.get(i)[0];
			if (load[i] != null) {
				lines.add("        " + load[i] + "   " + (tx == 0 ? ",x" : tx + ",x"));
				size += indexedSize(tx);
			}
			for (int k = 0; k < runs.get(i)[1]; k++) {
				if (y - base > 3) {
					int move = (y + 3 - base) * Geometry.STRIDE;
					lines.add("        leau  " + move + ",u");
					size += indexedSize(move);
					base = y + 3;
				}
				int off = (y - base) * Geometry.STRIDE;
				lines.add("        st" + reg[i] + "   " + (off == 0 ? ",u" : off + ",u"));
				size += indexedSize(off);
				y++;
			}
		}
		lines.add("        rts");
		return new Routine(h, lines, size + 1);
	}
}
