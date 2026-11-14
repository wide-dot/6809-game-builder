package com.widedot.toolbox.graphics.raycast;

/**
 * The raycaster's tables, in the fixed point formats its 6809 code reads :
 *
 * <pre>
 *   position   8.8 cells, unsigned
 *   angle      0-1023 a turn, 0 = east (+x), 256 = south (+y)
 *   directions s1.14 (1.0 = $4000)
 *   distances  8.8 cells
 * </pre>
 *
 * Per angle : the first column's ray direction rd0 = dir - plane x
 * (cols-1)/cols and the step between columns plane x 2/cols, plane being dir
 * turned a quarter and scaled by tan(fov / 2).
 */
final class RayTables {

	static final int ANGLES = 1024;
	static final int ONE = 1 << 14;
	/** the nearest a wall is seen : 1/8 cell */
	static final int PERP_MIN = 32;
	/** the samples table covers perp < 24 cells, a step of 1/64 cell */
	static final int NLEN = 1536;

	final Geometry g;
	final int[] sin = new int[ANGLES];
	/** per angle : rd0x, rd0y, stepx, stepy */
	final int[][] angles = new int[ANGLES][];
	/**
	 * |rd| >> 4 -> 1/|rd|, 8.8, capped at $7FFF. A ray's component is at
	 * most |dir| + |plane| : the table covers sqrt(1 + tan(fov / 2)^2), the
	 * 6809 code reads it without a test.
	 */
	final int[] recip;
	/** perp >> 2 -> samples */
	final int[] nsamp = new int[NLEN];
	/** samples -> the samples of the height a scaler exists for */
	final int[] snap;

	RayTables(Geometry g) {
		this.g = g;
		for (int a = 0; a < ANGLES; a++) {
			sin[a] = (int) Math.rint(ONE * Math.sin(2 * Math.PI * a / ANGLES));
		}
		double k = Math.tan(g.radians() / 2);
		int last = g.cols - 1;
		for (int a = 0; a < ANGLES; a++) {
			double dx = cos(a) / (double) ONE;
			double dy = sin[a] / (double) ONE;
			double px = -dy * k;
			double py = dx * k;
			angles[a] = new int[] { (int) Math.rint(ONE * (dx - px * last / g.cols)),
					(int) Math.rint(ONE * (dy - py * last / g.cols)), (int) Math.rint(ONE * (px * 2 / g.cols)),
					(int) Math.rint(ONE * (py * 2 / g.cols)) };
		}
		recip = new int[(int) (Math.sqrt(1 + k * k) * ONE / 16) + 8];
		for (int i = 0; i < recip.length; i++) {
			recip[i] = Math.min(0x7FFF, (int) Math.rint(256.0 * ONE / (i * 16 + 8)));
		}
		double projWall = g.projection() * g.wall;
		for (int i = 0; i < NLEN; i++) {
			double perp = (i * 4 + 2) / 256.0;
			nsamp[i] = g.quantize(projWall / perp) / g.unit();
		}
		snap = g.snap();
	}

	int cos(int a) {
		return sin[(a + ANGLES / 4) % ANGLES];
	}
}
