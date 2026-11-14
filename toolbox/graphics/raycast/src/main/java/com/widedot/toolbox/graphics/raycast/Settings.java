package com.widedot.toolbox.graphics.raycast;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;

/**
 * The view's settings, shared by {@code <wallscaler>} and {@code <raycast>} :
 * read on the element, else from {@code <default name="raycast.xxx">} — set
 * once, every form of both elements describes the same view.
 */
// the toolchain signals build errors with plain Exceptions
@SuppressWarnings("PMD.AvoidThrowingRawExceptionTypes")
final class Settings {

	/** screen byte columns and rows (BM16) */
	static final int SCREEN_COLS = 80;
	static final int SCREEN_ROWS = 200;

	final Geometry geometry;
	/** colour indexes of the flat ceiling and floor */
	final int ceil;
	final int floor;

	private Settings(Geometry geometry, int ceil, int floor) {
		this.geometry = geometry;
		this.ceil = ceil;
		this.floor = floor;
	}

	static String string(ImmutableNode node, BuildContext ctx, String name, String def) throws Exception {
		return Attribute.getString(node, ctx.defaults, name, "raycast." + name, def);
	}

	static int integer(ImmutableNode node, BuildContext ctx, String name, int def) throws Exception {
		String v = string(node, ctx, name, Integer.toString(def));
		try {
			return Integer.decode(v);
		} catch (NumberFormatException e) {
			throw new Exception(name + " : '" + v + "' is not a number");
		}
	}

	static double real(ImmutableNode node, BuildContext ctx, String name, double def) throws Exception {
		String v = string(node, ctx, name, Double.toString(def));
		try {
			return Double.parseDouble(v);
		} catch (NumberFormatException e) {
			throw new Exception(name + " : '" + v + "' is not a number");
		}
	}

	static Settings of(ImmutableNode node, BuildContext ctx) throws Exception {
		int lines = integer(node, ctx, "lines", 2);
		if (lines < 1 || lines > 8) {
			throw new Exception("lines : " + lines + " screen rows a wall sample, 1 to 8");
		}
		int unit = lines % 2 == 0 ? lines : 2 * lines;
		int[] view = view(node, ctx, lines, unit);
		int clipStep = integer(node, ctx, "clipstep", Math.max(8, unit));
		if (clipStep < unit || clipStep % unit != 0) {
			throw new Exception("clipstep : " + clipStep + " — a multiple of " + unit
					+ " (the rows between two wall heights, with lines=" + lines + ")");
		}
		int maxHeight = maxHeight(node, ctx, view[1], clipStep, unit);
		double fov = real(node, ctx, "fov", 66);
		if (fov < 10 || fov > 110) {
			throw new Exception("fov : " + fov + " degrees, 10 to 110");
		}
		double wall = real(node, ctx, "wall", 0.75);
		if (wall <= 0 || wall > 4) {
			throw new Exception("wall : " + wall + " — a wall's height in map cells, up to 4");
		}
		return new Settings(new Geometry(view[0], view[1], view[2], view[3], lines, clipStep, maxHeight, fov, wall),
				colour(node, ctx, "ceil", 1), colour(node, ctx, "floor", 2));
	}

	/** the view on the screen : cols, rows, x, y */
	private static int[] view(ImmutableNode node, BuildContext ctx, int lines, int unit) throws Exception {
		int cols = integer(node, ctx, "cols", SCREEN_COLS);
		int rows = integer(node, ctx, "rows", SCREEN_ROWS);
		int x = integer(node, ctx, "x", 0);
		int y = integer(node, ctx, "y", 0);
		if (rows < 2 * unit || rows % 2 != 0 || rows % unit != 0) {
			throw new Exception("rows : " + rows + " — an even number of rows, a multiple of " + unit
					+ " (the rows between two wall heights, with lines=" + lines + ")");
		}
		if (cols < 2 || cols % 2 != 0 || x < 0 || x % 2 != 0 || x + cols > SCREEN_COLS) {
			throw new Exception("cols=" + cols + " at x=" + x + " : byte columns (2 pixels each), both even, in the "
					+ SCREEN_COLS + " of the screen");
		}
		if (y < 0 || y + rows > SCREEN_ROWS) {
			throw new Exception("rows=" + rows + " at y=" + y + " : in the " + SCREEN_ROWS + " rows of the screen");
		}
		return new int[] { cols, rows, x, y };
	}

	/** the tallest wall drawn : by default 2.2 times the view's rows, on the clip grid */
	private static int maxHeight(ImmutableNode node, BuildContext ctx, int rows, int clipStep, int unit)
			throws Exception {
		int maxHeight = integer(node, ctx, "maxheight", rows + clipStep * (int) Math.rint(1.2 * rows / clipStep));
		if (maxHeight < rows || (maxHeight - rows) % clipStep != 0) {
			throw new Exception("maxheight : " + maxHeight + " — the view's rows (" + rows + ") plus a multiple of"
					+ " clipstep (" + clipStep + ")");
		}
		if (maxHeight / unit > 255) {
			throw new Exception("maxheight : " + maxHeight + " — " + (maxHeight / unit) + " heights of " + unit
					+ " rows, a height's index is a byte (255 at most) : lower maxheight or raise lines");
		}
		return maxHeight;
	}

	private static int colour(ImmutableNode node, BuildContext ctx, String name, int def) throws Exception {
		int c = integer(node, ctx, name, def);
		if (c < 0 || c > 15) {
			throw new Exception(name + " : " + c + " — a colour index, 0 to 15");
		}
		return c;
	}

	String describe() {
		Geometry g = geometry;
		return g.cols + "x" + g.rows + " at (" + g.x + "," + g.y + "), lines=" + g.lines + ", clipstep=" + g.clipStep
				+ ", maxheight=" + g.maxHeight;
	}
}
