package com.widedot.toolbox.graphics.raycast;

/**
 * The raycaster in fixed point : what the engine's 6809 code
 * (engine/graphics/raycast/raycast.unit.asm) computes, bit for bit.
 *
 * Per column (Lodev's DDA on a non normalised ray, whose side distances are
 * perpendicular distances : no fish-eye correction) :
 *
 * <pre>
 *   delta  = RECIP[|rd| >> 4]                    8.8, capped at $7FFF
 *   side0  = f x delta >> 8, f = the cell fraction to the first line (1-256)
 *   step   x while sideX < sideY, else y ; stop on a wall cell
 *   perp   = side - delta                        (clamped >= PERP_MIN)
 *   u      = frac(pos + (perp x r >> 7) x sign(rd')) >> 2, r = |rd'| >> 7
 *            (8 bits : the error is perp / 256 cell, a quarter of what one
 *            column spans at that distance), mirrored on the faces seen
 *            from +x / -y
 *   n      = NSAMP[perp >> 2]                    samples
 * </pre>
 *
 * Columns : a ray for the even columns and the last one ; with pairing, an
 * odd column whose two neighbours hit the same cell on the same side lies
 * on the same plane face — the wall's height is linear in screen x there,
 * so its samples are the neighbours' mean and its texture column their mean
 * (the addresses' mean, cleared to the column) ; otherwise it casts its own
 * ray. A column's samples go through SNAP.
 */
final class RayModel {

	private final RayTables t;
	private final GridMap map;
	private final boolean pair;

	/** a ray's hit */
	static final class Hit {
		int texture;
		int u;
		int perp;
		int cell;
		int side;
	}

	/** a frame : per column the samples and the texture column's address ; the rays cast */
	static final class Frame {
		final int[] samples;
		final int[] texture;
		int rays;

		Frame(int cols) {
			samples = new int[cols];
			texture = new int[cols];
		}
	}

	RayModel(RayTables t, GridMap map, boolean pair) {
		this.t = t;
		this.map = map;
		this.pair = pair;
	}

	Hit cast(int px, int py, int rdx, int rdy) {
		Hit h = walk(px, py, rdx, rdy);
		h.u = column(h, px, py, rdx, rdy);
		return h;
	}

	/** the first side distance : the cell fraction to the first line, times delta */
	private static int first(int pos, int rd, int delta) {
		int f = pos & 255;
		return ((rd < 0 ? f : 256 - f) * delta) >> 8;
	}

	/** the DDA : the wall cell, the face, the perpendicular distance */
	private Hit walk(int px, int py, int rdx, int rdy) {
		// no clamp : the 6809 code has none, the table covers every ray of the view
		int dx = t.recip[Math.abs(rdx) >> 4];
		int dy = t.recip[Math.abs(rdy) >> 4];
		int sx = first(px, rdx, dx);
		int sy = first(py, rdy, dy);
		int stx = rdx < 0 ? -1 : 1;
		int sty = rdy < 0 ? -map.width : map.width;
		Hit h = new Hit();
		h.cell = (py >> 8) * map.width + (px >> 8);
		do {
			if (sx < sy) {
				sx += dx;
				h.cell += stx;
				h.side = 0;
			} else {
				sy += dy;
				h.cell += sty;
				h.side = 1;
			}
			if (sx >= 65536 || sy >= 65536) {
				throw new IllegalStateException("a side distance leaves 16 bits");
			}
		} while (map.cells[h.cell] == 0);
		h.perp = Math.max(RayTables.PERP_MIN, h.side == 0 ? sx - dx : sy - dy);
		h.texture = map.cells[h.cell];
		return h;
	}

	/** the texture column of a hit, 0-63 */
	private static int column(Hit h, int px, int py, int rdx, int rdy) {
		int rd = h.side == 0 ? rdy : rdx;
		int base = h.side == 0 ? py : px;
		boolean mirror = h.side == 0 ? rdx < 0 : rdy > 0;
		int r = Math.abs(rd) >> 7;
		if (r > 255) {
			throw new IllegalStateException("a ray's component leaves 8 bits");
		}
		int low = ((h.perp * r) >> 7) & 255;
		if (rd < 0) {
			low = (256 - low) & 255;
		}
		int u = ((base + low) & 255) >> 2;
		return mirror ? 63 - u : u;
	}

	/** the frame seen from (px, py) 8.8 at angle a, textures at their address */
	Frame frame(int px, int py, int a, int textures) {
		int cols = t.g.cols;
		Frame f = new Frame(cols);
		int[] cell = new int[cols];
		int[] side = new int[cols];
		ray(f, cell, side, 0, px, py, a, textures);
		for (int c = 1; c < cols - 1; c += 2) {
			ray(f, cell, side, c + 1, px, py, a, textures);
			if (pair && cell[c - 1] == cell[c + 1] && side[c - 1] == side[c + 1]) {
				f.samples[c] = (f.samples[c - 1] + f.samples[c + 1]) >> 1;
				f.texture[c] = ((f.texture[c - 1] + f.texture[c + 1]) >> 1) & ~63;
			} else {
				ray(f, cell, side, c, px, py, a, textures);
			}
		}
		ray(f, cell, side, cols - 1, px, py, a, textures);
		for (int c = 0; c < cols; c++) {
			f.samples[c] = t.snap[f.samples[c]];
		}
		return f;
	}

	private void ray(Frame f, int[] cell, int[] side, int c, int px, int py, int a, int textures) {
		int[] ang = t.angles[a];
		Hit h = cast(px, py, ang[0] + c * ang[2], ang[1] + c * ang[3]);
		f.rays++;
		f.samples[c] = t.nsamp[Math.min(h.perp >> 2, RayTables.NLEN - 1)];
		f.texture[c] = textures + (h.texture - 1) * Geometry.TEX * Geometry.TEX + h.u * Geometry.TEX;
		cell[c] = h.cell;
		side[c] = h.side;
	}
}
