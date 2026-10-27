package com.widedot.toolbox.graphics.spritestream;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;
import java.util.Random;
import java.util.TreeMap;

import org.junit.jupiter.api.Test;

/**
 * guard : a record carries what its draw saves, whole and cut. Checked
 * against two counts that share no code with the bounds : what the generated
 * walker routines push (their bodies' pushes, then the restore code and Y),
 * stored and mirrored, equal to the whole bound ; and what the clip mode
 * pushes on random windows (a wholly visible record by its routine, each
 * visible row of a cut one its visible bytes then 3 bytes for one, 4 for
 * more : spritestream.clip.eol), at most the cut bound.
 */
class GuardTest {

	private static final Map<Integer, Integer> NONE = new TreeMap<Integer, Integer>();

	private static Map<Integer, Integer> rows() {
		Map<Integer, Integer> rows = new TreeMap<Integer, Integer>();
		rows.put(2, 2);
		rows.put(3, 3);
		return rows;
	}

	/** what a whole draw of the stream pushes, through the walker's own routine bodies */
	private static int drawPushes(Options o, Walker w, byte[] s, boolean mirrored) throws Exception {
		int u = o.mirrorable ? 1 : 0;
		int total = 0;
		while (true) {
			int code = s[u] & 0xFF;
			u += 2;
			if (code == o.code("end")) {
				return total;
			}
			if (code == o.code("nop")) {
				u += o.mirrorable ? 1 : 0;
				continue;
			}
			Shape sh = o.shape(code);
			Walker.Body b = mirrored ? w.bodyM(sh, 0, 0) : w.bodyN(sh, 0, 0);
			for (int[] p : b.pushed) {
				total += p[0];
			}
			total += 3;                                // pshs y,b : the restore code and Y
			u += sh.rows * sh.rowBytes() + (o.mirrorable ? 1 : 0);
		}
	}

	/** what a clipped draw pushes : rows [rt, rb), box bytes [jl, jr) visible (stored facing) */
	private static int clipPushes(Options o, Walker w, byte[] s, int rt, int rb, int jl, int jr) throws Exception {
		int u = o.mirrorable ? 1 : 0;
		int y = -Walker.LINE;
		int total = 0;
		while (true) {
			int code = s[u] & 0xFF;
			y += (byte) s[u + 1];
			u += 2;
			if (code == o.code("end")) {
				return total;
			}
			if (code == o.code("nop")) {
				u += o.mirrorable ? 1 : 0;
				continue;
			}
			Shape sh = o.shape(code);
			int row = Math.floorDiv(y, Walker.LINE), col = Math.floorMod(y, Walker.LINE);
			int lo = 2 * col + sh.p;
			boolean whole = row >= rt && row + sh.rows <= rb && lo >= jl && lo + sh.n <= jr;
			if (whole) {
				for (int[] p : w.bodyN(sh, 0, 0).pushed) {
					total += p[0];
				}
				total += 3;
			} else {
				for (int k = 0; k < sh.rows; k++) {
					int r = row + k;
					int seen = Math.min(lo + sh.n, jr) - Math.max(lo, jl);
					if (r >= rt && r < rb && seen > 0) {
						total += seen + (seen == 1 ? 3 : 4);
					}
				}
			}
			u += sh.rows * sh.rowBytes() + (o.mirrorable ? 1 : 0);
			if (sh.advances()) {
				y += Walker.LINE * (sh.rows - 1);
			}
		}
	}

	@Test
	void theBoundHoldsEveryDrawWholeOrCut() throws Exception {
		Random r = new Random(1989);
		Options[] sets = {
				new Options(6, rows(), true, true, false, true, true, true),
				new Options(8, NONE, false, true, false, true, true, true),
				new Options(4, rows(), true, true, true, false, true, true),
		};
		int draws = 0;
		int tight = 0;
		for (Options o : sets) {
			Encoder enc = new Encoder(o);
			Walker w = new Walker(o);
			for (int k = 0; k < 100; k++) {
				int wd = 2 * (1 + r.nextInt(40)), h = 1 + r.nextInt(70);
				Picture p = new Picture("random" + k, EncoderTest.pixels(r, wd, h));
				byte[] s = enc.stream(p.bytes);
				int bound = Decoder.saveBound(o, s, true);
				int whole = drawPushes(o, w, s, false);
				assertEquals(whole, Decoder.saveBound(o, s, false), p.file + " : the whole draw's count");
				if (o.mirrorable) {
					assertEquals(whole, drawPushes(o, w, s, true), p.file + " : the facings push the same");
				}
				int n = p.bytes.length == 0 ? 0 : p.bytes[0].length;
				for (int c = 0; c < 30; c++) {
					int rt = r.nextInt(h + 1), rb = rt + r.nextInt(h + 1 - rt);
					int jl = r.nextInt(n + 1), jr = jl + r.nextInt(n + 1 - jl);
					int cut = clipPushes(o, w, s, rt, rb, jl, jr);
					assertTrue(cut <= bound, p.file + " : a draw cut to rows " + rt + "-" + rb + ", bytes " + jl + "-"
							+ jr + " pushes " + cut + ", past the bound " + bound);
					draws++;
				}
				tight += bound - whole;
			}
		}
		assertEquals(9000, draws);
		assertTrue(tight > 0, "the bound counts the cut rows' overhead above a whole draw");
	}

	@Test
	void theRecordCarriesItsBoundAndTheWalkersDeclareTheGuard() throws Exception {
		Options o = new Options(6, rows(), true, true, false, true, true, true);
		Random r = new Random(7);
		Picture b = new Picture("p", EncoderTest.pixels(r, 16, 12));
		SpritestreamPlugin.Encoded e = SpritestreamPlugin.encode(o, new Encoder(o),
				new SpritestreamPlugin.Sprite("p", b, null));
		String src = SpritestreamPlugin.source(o, e);
		assertTrue(e.bound > 0);
		assertTrue(e.cutBound > e.bound);
		assertTrue(src.contains("        fdb   " + e.bound + "," + e.cutBound + " "), src);
		assertEquals(12 + e.s0.length, e.bytes());
		assertTrue(new Walker(o).source().contains("spritestream.GUARD equ 1"));

		Options plain = new Options(6, rows(), true, true, false, true, true);
		SpritestreamPlugin.Encoded p = SpritestreamPlugin.encode(plain, new Encoder(plain),
				new SpritestreamPlugin.Sprite("p", b, null));
		String psrc = SpritestreamPlugin.source(plain, p);
		assertEquals(8 + p.s0.length, p.bytes());
		assertFalse(psrc.contains("guard"), psrc);
		assertFalse(new Walker(plain).source().contains("GUARD"));
	}

	@Test
	void aGuardNeedsTheSave() {
		Exception e = assertThrows(Exception.class, () -> new Options(6, NONE, true, false, false, true, true, true));
		assertTrue(e.getMessage().contains("guard needs save"), e.getMessage());
	}
}
