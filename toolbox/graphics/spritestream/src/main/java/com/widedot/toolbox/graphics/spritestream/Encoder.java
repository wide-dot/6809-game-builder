package com.widedot.toolbox.graphics.spritestream;

import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.List;

/**
 * A picture's screen bytes to a stream of records, one record a row segment
 * (the screen bytes from the first to the last non transparent byte of a row,
 * cut every segment bytes ; transparent bytes inside a segment are masked).
 * Consecutive rows that each hold one same segment (first byte, length) are
 * one multi-row record, up to the rows the shape set has for that length.
 * With opaque segments, a row is cut into masked and opaque segments (whole
 * bytes only, no mask) at the least cycles of the walkers' routines.
 *
 * Record : [mirrored delta] (mirrorable only) [code] [delta] [payload], the
 * deltas being the change of Y : rows x 40 + columns, Y on the segment's first
 * byte's column (stored facing) or on the column of the mirrored position of
 * that byte (mirrored facing : the box's byte N - 1 - j). Before the first
 * record Y is one row above the box, at column 0 (stored) or (N - 1) / 2
 * (mirrored). A delta past a signed byte inserts nop records (a row each).
 * The stream ends with the end record.
 */
final class Encoder {

	static final int LINE = 40;

	/** a record to emit : a segment of row r, first byte j0, n bytes, rows */
	static final class Segment {
		final int row;
		final int j0;
		final int n;
		int rows;
		final boolean single;
		final boolean opaque;

		Segment(int row, int j0, int n, int rows, boolean single, boolean opaque) {
			this.row = row;
			this.j0 = j0;
			this.n = n;
			this.rows = rows;
			this.single = single;
			this.opaque = opaque;
		}

		Shape shape() {
			return new Shape(j0 & 1, n, rows, opaque);
		}
	}

	private final Options o;
	private final Walker costs;

	Encoder(Options o) {
		this.o = o;
		this.costs = o.opaque ? new Walker(o) : null;
	}

	static boolean empty(int[] b) {
		return b[0] == 0xFF;
	}

	static boolean full(int[] b) {
		return b[0] == 0;
	}

	/** the records of a picture, in stream order */
	List<Segment> segments(int[][][] vb) {
		List<Segment> segs = new ArrayList<Segment>();
		for (int r = 0; r < vb.length; r++) {
			int[][] line = vb[r];
			if (o.opaque) {
				List<int[]> row = split(line);
				for (int[] s : row) {
					boolean op = s[2] == 1;
					segs.add(new Segment(r, s[0], s[1], 1, row.size() == 1 && !op, op));
				}
				continue;
			}
			int first = -1, last = -1;
			for (int j = 0; j < line.length; j++) {
				if (!empty(line[j])) {
					if (first < 0) {
						first = j;
					}
					last = j + 1;
				}
			}
			if (first < 0) {
				continue;
			}
			int j0 = first;
			while (j0 < last) {
				int n = Math.min(o.segment, last - j0);
				segs.add(new Segment(r, j0, n, 1, j0 == first && j0 + n == last, false));
				j0 += n;
			}
		}
		// consecutive single-segment rows of the same segment : one record
		List<Segment> out = new ArrayList<Segment>();
		for (Segment s : segs) {
			if (!out.isEmpty()) {
				Segment q = out.get(out.size() - 1);
				if (s.single && q.single && !s.opaque && !q.opaque && s.j0 == q.j0 && s.n == q.n
						&& s.row == q.row + q.rows && q.rows < o.maxRows(s.n)) {
					q.rows++;
					continue;
				}
			}
			out.add(s);
		}
		return out;
	}

	/**
	 * The cut of a row into masked and opaque segments at the least cycles
	 * (dynamic programming over the routines' cycles) : {j0, n, opaque}.
	 * Transparent bytes are skipped or masked, a segment neither starts nor
	 * ends on one, an opaque segment holds whole bytes only.
	 */
	List<int[]> split(int[][] line) {
		int w = line.length;
		long inf = Long.MAX_VALUE / 4;
		long[] best = new long[w + 1];
		int[][] choice = new int[w + 1][];
		java.util.Arrays.fill(best, inf);
		best[0] = 0;
		for (int i = 0; i < w; i++) {
			if (best[i] == inf) {
				continue;
			}
			if (empty(line[i])) {
				if (best[i] < best[i + 1]) {
					best[i + 1] = best[i];
					choice[i + 1] = new int[] { -1, i };
				}
				continue;
			}
			for (int j = i + 1; j <= Math.min(w, i + o.segment); j++) {
				if (empty(line[j - 1])) {
					continue;
				}
				int n = j - i, p = i & 1;
				long c = best[i] + costs.cost(new Shape(p, n, 1, false));
				if (c < best[j]) {
					best[j] = c;
					choice[j] = new int[] { 0, i };
				}
				boolean whole = true;
				for (int k = i; k < j; k++) {
					whole &= full(line[k]);
				}
				if (whole) {
					c = best[i] + costs.cost(new Shape(p, n, 1, true));
					if (c < best[j]) {
						best[j] = c;
						choice[j] = new int[] { 1, i };
					}
				}
			}
		}
		List<int[]> segs = new ArrayList<int[]>();
		int j = w;
		while (j > 0) {
			int[] ch = choice[j];
			if (ch[0] >= 0) {
				segs.add(0, new int[] { ch[1], j - ch[1], ch[0] });
			}
			j = ch[1];
		}
		return segs;
	}

	/** the stream of a picture's screen bytes */
	byte[] stream(int[][][] vb) {
		int width = vb.length == 0 ? 0 : vb[0].length;
		int curR = -1, curC = 0, curCm = (width - 1) >> 1;
		ByteArrayOutputStream out = new ByteArrayOutputStream();
		for (Segment s : segments(vb)) {
			int c = s.j0 >> 1, cm = (width - 1 - s.j0) >> 1;
			int delta, dm;
			while (true) {
				delta = (s.row - curR) * LINE + c - curC;
				dm = (s.row - curR) * LINE + cm - curCm;
				if (delta >= -128 && delta <= 127 && (!o.mirrorable || (dm >= -128 && dm <= 127))) {
					break;
				}
				record(out, LINE, LINE, o.code("nop"));
				curR++;
			}
			record(out, dm, delta, o.code(s.shape()));
			for (int t = 0; t < s.rows; t++) {
				int[][] seg = new int[s.n][];
				for (int i = 0; i < s.n; i++) {
					seg[i] = vb[s.row + t][s.j0 + i];
				}
				byte[] p = Shape.payload(seg, s.opaque);
				out.write(p, 0, p.length);
			}
			curR = s.row + (s.shape().advances() ? s.rows - 1 : 0);
			curC = c;
			curCm = cm;
		}
		record(out, 0, 0, o.code("end"));
		return out.toByteArray();
	}

	private void record(ByteArrayOutputStream out, int dm, int delta, int code) {
		if (o.mirrorable) {
			out.write(dm & 0xFF);
		}
		out.write(code & 0xFF);
		out.write(delta & 0xFF);
	}
}
