package com.widedot.toolbox.graphics.spritestream;

/**
 * The self-check : a stream read the way the walkers read it, its records
 * applied to a box of screen bytes, for either facing. Each box byte ends as
 * the composition of every write it received ({mask, data} : screen AND mask
 * OR data), which must equal the picture's byte (mirrored : the picture's
 * mirror), a byte the picture leaves transparent included.
 */
final class Decoder {

	private Decoder() {
	}

	/** the box's bytes after the walk : out[row][j] = {mask, data} */
	static int[][][] walk(Options o, byte[] s, int width, int height, boolean mirrored) throws Exception {
		int[][][] box = new int[height][width][];
		for (int r = 0; r < height; r++) {
			for (int j = 0; j < width; j++) {
				box[r][j] = new int[] { 0xFF, 0 };
			}
		}
		int q = (width - 1) & 1;
		int u = 0;
		int y = -Walker.LINE + (mirrored ? (width - 1) >> 1 : 0);
		if (!mirrored && o.mirrorable) {
			u = 1;
		}
		for (int guard = 0;; guard++) {
			if (guard > 100000 || u + 2 > s.length) {
				throw new Exception("stream runs past its end");
			}
			int code;
			if (mirrored) {
				y += (byte) s[u];
				code = s[u + 1] & 0xFF;
				u += 3;
			} else {
				code = s[u] & 0xFF;
				y += (byte) s[u + 1];
				u += 2;
			}
			if (code == o.code("end")) {
				break;
			}
			if (code == o.code("nop")) {
				if (!mirrored && o.mirrorable) {
					u++;
				}
				continue;
			}
			Shape sh = o.shape(code);
			if (sh == null || code % 2 != 0 || code / 2 >= o.names.size()) {
				throw new Exception("unknown record code " + code);
			}
			int row = Math.floorDiv(y, Walker.LINE), col = Math.floorMod(y, Walker.LINE);
			int[][] offs = Shape.offsets(sh.n, sh.opaque);
			int pm = sh.p ^ q;
			for (int t = 0; t < sh.rows; t++) {
				int base = u + t * sh.rowBytes();
				for (int i = 0; i < sh.n; i++) {
					int j = mirrored ? 2 * col + pm - i : 2 * col + sh.p + i;
					int r = row + t;
					if (r < 0 || r >= height || j < 0 || j >= width) {
						throw new Exception("record " + sh.name() + " writes outside the box, row " + r + " byte " + j);
					}
					int m = sh.opaque ? 0 : s[base + offs[i][0]] & 0xFF;
					int d = s[base + offs[i][1]] & 0xFF;
					if (mirrored) {
						m = Picture.rev(m);
						d = Picture.rev(d);
					}
					int[] b = box[r][j];
					box[r][j] = new int[] { b[0] & m, (b[1] & m) | d };
				}
			}
			u += sh.rows * sh.rowBytes();
			if (!mirrored && o.mirrorable) {
				u++;
			}
			if (sh.advances()) {
				y += Walker.LINE * (sh.rows - 1);
			}
		}
		if (u != s.length) {
			throw new Exception("stream has " + (s.length - u) + " bytes past its end record");
		}
		return box;
	}

	/**
	 * what a draw of the stream pushes on the save stack, either facing :
	 * whole (cut false), exactly, a record the n bytes of each of its rows then
	 * its restore code and Y (3 bytes) ; cut by the clip mode (cut true), at
	 * most, each visible row of a record its visible bytes then 3 or 4 bytes
	 * (spritestream.clip.eol), a wholly visible record its routine : n x rows
	 * + 4 x rows a record bounds both.
	 */
	static int saveBound(Options o, byte[] s, boolean cut) throws Exception {
		int u = o.mirrorable ? 1 : 0;
		int bound = 0;
		for (int guard = 0;; guard++) {
			if (guard > 100000 || u + 2 > s.length) {
				throw new Exception("stream runs past its end");
			}
			int code = s[u] & 0xFF;
			u += 2;
			if (code == o.code("end")) {
				return bound;
			}
			if (code == o.code("nop")) {
				u += o.mirrorable ? 1 : 0;
				continue;
			}
			Shape sh = o.shape(code);
			bound += cut ? (sh.n + 4) * sh.rows : sh.n * sh.rows + 3;
			u += sh.rows * sh.rowBytes() + (o.mirrorable ? 1 : 0);
		}
	}

	/** the stream drawn in a facing equals the picture's bytes, else the first difference */
	static void check(Options o, byte[] s, int[][][] vb, boolean mirrored, String what) throws Exception {
		int h = vb.length, w = h == 0 ? 0 : vb[0].length;
		int[][][] want = mirrored ? Picture.mirror(vb) : vb;
		int[][][] got = walk(o, s, w, h, mirrored);
		for (int r = 0; r < h; r++) {
			for (int j = 0; j < w; j++) {
				if (got[r][j][0] != want[r][j][0] || got[r][j][1] != want[r][j][1]) {
					throw new Exception(what + (mirrored ? " (mirrored)" : "") + " : the stream draws row " + r
							+ " byte " + j + String.format(" as mask $%02X data $%02X, the picture holds $%02X $%02X",
									got[r][j][0], got[r][j][1], want[r][j][0], want[r][j][1]));
				}
			}
		}
	}
}
