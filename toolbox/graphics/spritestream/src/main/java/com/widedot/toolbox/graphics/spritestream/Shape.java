package com.widedot.toolbox.graphics.spritestream;

/**
 * A record shape : the walkers have one routine per shape (and per plane
 * parity of the box). {@code p} is the plane of the segment's first byte
 * (0 : the box's first byte's plane), {@code n} its screen bytes, {@code rows}
 * the rows it draws (the same segment on consecutive rows), {@code opaque}
 * whether its bytes are whole (data only) or masked (mask and data).
 */
final class Shape {

	final int p;
	final int n;
	final int rows;
	final boolean opaque;

	Shape(int p, int n, int rows, boolean opaque) {
		this.p = p;
		this.n = n;
		this.rows = rows;
		this.opaque = opaque;
	}

	/** m0_3, m1_2r2, o0_4... : the routine's name */
	String name() {
		return (opaque ? "o" : "m") + p + "_" + n + (rows > 1 ? "r" + rows : "");
	}

	/** the same segment with its first byte on the other plane */
	Shape flip() {
		return new Shape(p ^ 1, n, rows, opaque);
	}

	/** payload bytes of one row : mask and data a byte, data alone when opaque */
	int rowBytes() {
		return opaque ? n : 2 * n;
	}

	/** a record of 3 rows or more leaves the walker on its last row ; 2 rows leave it on the first */
	boolean advances() {
		return rows >= 3;
	}

	@Override
	public boolean equals(Object o) {
		if (!(o instanceof Shape)) {
			return false;
		}
		Shape s = (Shape) o;
		return s.p == p && s.n == n && s.rows == rows && s.opaque == opaque;
	}

	@Override
	public int hashCode() {
		return ((p * 31 + n) * 31 + rows) * 2 + (opaque ? 1 : 0);
	}

	@Override
	public String toString() {
		return name();
	}

	// ---------------------------------------------------------------- payload

	/**
	 * The payload order of a segment of n bytes, independent of p : the bytes
	 * of even index first, then the odd ones ; inside a group, pairs (i, i+2)
	 * (same plane, adjacent columns : one 16 bit access) then a last single.
	 * Each entry is the list of the group's byte indexes.
	 */
	static java.util.List<int[]> groups(int n) {
		java.util.List<int[]> out = new java.util.ArrayList<int[]>();
		for (int par = 0; par < 2; par++) {
			java.util.List<Integer> idx = new java.util.ArrayList<Integer>();
			for (int i = par; i < n; i += 2) {
				idx.add(i);
			}
			while (idx.size() >= 2) {
				out.add(new int[] { idx.get(0), idx.get(1) });
				idx = idx.subList(2, idx.size());
			}
			if (!idx.isEmpty()) {
				out.add(new int[] { idx.get(0) });
			}
		}
		return out;
	}

	/**
	 * Offsets of byte i's mask and data in one row's payload : masked groups
	 * hold their masks then their data, opaque groups their data alone (mask
	 * offset -1).
	 */
	static int[][] offsets(int n, boolean opaque) {
		int[][] out = new int[n][];
		int o = 0;
		for (int[] g : groups(n)) {
			int k = g.length;
			for (int t = 0; t < k; t++) {
				out[g[t]] = opaque ? new int[] { -1, o + t } : new int[] { o + t, o + k + t };
			}
			o += opaque ? k : 2 * k;
		}
		return out;
	}

	/** one row's payload of a segment : seg[i] = {mask, data} */
	static byte[] payload(int[][] seg, boolean opaque) {
		java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
		for (int[] g : groups(seg.length)) {
			if (!opaque) {
				for (int i : g) {
					out.write(seg[i][0]);
				}
			}
			for (int i : g) {
				out.write(seg[i][1]);
			}
		}
		return out.toByteArray();
	}
}
