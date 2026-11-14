package com.widedot.toolbox.graphics.raycast;

import java.util.ArrayList;
import java.util.List;

/**
 * The view's geometry : which wall heights a scaler exists for, how a
 * projected height snaps to one of them, which texel each of its rows shows.
 * Everything the scalers, the columns unit and the raycaster's tables share.
 *
 * A wall column is drawn in samples : {@code lines} screen rows of the same
 * texel. A height is a number of rows, a multiple of the height unit — the
 * lines of a sample, doubled when odd : a wall is centred in the view, so
 * its height is even. Up to the view's rows every multiple has its routine,
 * above (a wall taller than the view, clipped to it) one every
 * {@code clipStep} rows, up to {@code maxHeight}. The raycaster names a
 * height by its index, the height over the unit.
 */
final class Geometry {

	/** bytes a screen row in a bank (BM16 : 40) */
	static final int STRIDE = 40;
	/** texels a texture column, columns a texture */
	static final int TEX = 64;
	/** a scaler's U points BIAS rows under the row it writes : offsets -120..+120 keep 8 bits */
	static final int BIAS = 3;

	/** the view : byte columns (2 pixels each), rows, its top left in byte columns and rows */
	final int cols;
	final int rows;
	final int x;
	final int y;
	/** screen rows a wall sample */
	final int lines;
	/** above the view's rows, a routine every clipStep rows of height */
	final int clipStep;
	/** the tallest wall a scaler draws (taller : clamped) */
	final int maxHeight;
	/** the field of view, degrees ; a wall's height in map cells */
	final double fov;
	final double wall;

	Geometry(int cols, int rows, int x, int y, int lines, int clipStep, int maxHeight, double fov, double wall) {
		this.cols = cols;
		this.rows = rows;
		this.x = x;
		this.y = y;
		this.lines = lines;
		this.clipStep = clipStep;
		this.maxHeight = maxHeight;
		this.fov = fov;
		this.wall = wall;
	}

	/** rows between two heights : the lines of a sample, even */
	int unit() {
		return lines % 2 == 0 ? lines : 2 * lines;
	}

	/** the index of the tallest wall */
	int indexMax() {
		return maxHeight / unit();
	}

	/** texels a sample, 8.8, floored : the last sample never reaches TEX */
	static int stepOf(int samples) {
		return (TEX * 256) / samples;
	}

	/** the texel of each row of a wall h rows high */
	int[] texelRows(int h) {
		int n = h / lines;
		int s = stepOf(n);
		int pos = s / 2;
		int[] out = new int[n * lines];
		for (int r = 0; r < out.length; r++) {
			out[r] = (pos + (r / lines) * s) >> 8;
		}
		return out;
	}

	/** the heights a routine exists for, growing */
	List<Integer> heights() {
		List<Integer> out = new ArrayList<Integer>();
		for (int h = unit(); h <= rows; h += unit()) {
			out.add(h);
		}
		for (int h = rows + clipStep; h <= maxHeight; h += clipStep) {
			out.add(h);
		}
		return out;
	}

	/** a projected height to the nearest one a routine exists for */
	int quantize(double h) {
		if (h <= rows) {
			return unit() * Math.max(1, (int) Math.rint(h / unit()));
		}
		return Math.min(maxHeight, rows + clipStep * Math.max(1, (int) Math.rint((h - rows) / clipStep)));
	}

	/** the first row of a centred wall h rows high, in the view (negative : clipped) */
	int topRow(int h) {
		return Math.floorDiv(rows - h, 2);
	}

	/** a height's index -> the index of the height a scaler exists for */
	int[] snap() {
		int[] out = new int[indexMax() + 1];
		for (int n = 1; n < out.length; n++) {
			out[n] = quantize((double) (n * unit())) / unit();
		}
		return out;
	}

	/**
	 * The distance of the projection plane, in rows : half the view's width
	 * in row units (a column is 2 BM16 pixels, a BM16 pixel is 5/3 as wide
	 * as it is tall on a 4:3 screen) over tan(fov / 2).
	 */
	double projection() {
		double halfWidth = (cols / 2.0) * 2 * (4.0 / 3) / (160.0 / 200);
		return halfWidth / Math.tan(radians() / 2);
	}

	double radians() {
		return fov * (Math.PI / 180.0);
	}

	/** a byte column's row 0 in the data window : even columns in the $C000 bank */
	int columnAddress(int c) {
		int col = x + c;
		return ((col & 1) == 0 ? 0xC000 : 0xA000) + (col >> 1) + y * STRIDE;
	}
}
