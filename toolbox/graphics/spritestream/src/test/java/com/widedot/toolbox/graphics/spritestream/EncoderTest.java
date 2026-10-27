package com.widedot.toolbox.graphics.spritestream;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;
import java.util.Random;
import java.util.TreeMap;

import org.junit.jupiter.api.Test;

/**
 * The encoder against its own decoder over shape sets the prototype did not
 * cover (one facing, opaque segments, long and multi-row segments), on random
 * pictures : every stream draws its picture, both facings when mirrorable ;
 * and the sprite checks the builder refuses a sprite with.
 */
class EncoderTest {

	static int[][] pixels(Random r, int w, int h) {
		int[][] px = new int[h][w];
		int mode = r.nextInt(3);
		for (int y = 0; y < h; y++) {
			int a = r.nextInt(w), b = a + r.nextInt(w - a);
			for (int x = 0; x < w; x++) {
				boolean on = mode == 0 ? x >= a && x <= b : mode == 1 ? r.nextInt(3) > 0 : (y / 3 + x / 5) % 2 == 0;
				px[y][x] = on ? r.nextInt(4) : -1;
			}
			if (mode == 2 && y % 7 == 3) {
				java.util.Arrays.fill(px[y], -1);         // empty rows : nop records
			}
		}
		return px;
	}

	@Test
	void everyStreamDrawsItsPicture() throws Exception {
		Random r = new Random(6809);
		Map<Integer, Integer> none = new TreeMap<Integer, Integer>();
		Map<Integer, Integer> rows = new TreeMap<Integer, Integer>();
		rows.put(2, 2);
		rows.put(3, 3);
		rows.put(4, 4);
		Options[] sets = {
				new Options(6, rows, true, true, false, true),
				new Options(8, none, false, true, false, true),
				new Options(8, none, false, false, true, true),
				new Options(4, rows, true, true, true, false),
				new Options(15, none, true, true, false, true),
				new Options(1, none, true, false, false, true),
		};
		int n = 0;
		for (Options o : sets) {
			Encoder enc = new Encoder(o);
			for (int k = 0; k < 120; k++) {
				int w = 2 * (1 + r.nextInt(40)), h = 1 + r.nextInt(70);
				Picture p = new Picture("random" + k, pixels(r, w, h));
				byte[] s = enc.stream(p.bytes);
				Decoder.check(o, s, p.bytes, false, p.file);
				if (o.mirrorable) {
					Decoder.check(o, s, p.bytes, true, p.file);
				}
				n++;
			}
		}
		assertEquals(720, n);
	}

	@Test
	void opaqueSegmentsAreChosenWhenCheaper() throws Exception {
		Options o = new Options(8, new TreeMap<Integer, Integer>(), false, false, true, true);
		int[][] px = new int[4][64];
		for (int[] row : px) {
			java.util.Arrays.fill(row, 2);                 // whole bytes only
		}
		Picture p = new Picture("solid", px);
		boolean opaque = false;
		for (Encoder.Segment s : new Encoder(o).segments(p.bytes)) {
			opaque |= s.opaque;
		}
		assertTrue(opaque, "a solid picture is drawn with opaque segments");
	}

	@Test
	void aSpriteIsChecked() throws Exception {
		Options o = PrototypeTest.reco();
		Encoder enc = new Encoder(o);
		Random r = new Random(1);
		int[][] base = pixels(r, 10, 12);
		int[][] shifted = new int[12][12];
		for (int y = 0; y < 12; y++) {
			shifted[y][0] = shifted[y][1] = -1;
			System.arraycopy(base[y], 0, shifted[y], 2, 10);
		}
		SpritestreamPlugin.Encoded e = SpritestreamPlugin.encode(o, enc, new SpritestreamPlugin.Sprite("ok",
				new Picture("a", base), new Picture("b", shifted)));
		assertEquals(3, e.n0);
		assertEquals(3, e.n1);
		assertEquals(1, e.flag);                             // 10 mod 4 = 2 : the mirror swaps the steps
		shifted[5][2] = (shifted[5][2] + 2) % 4;
		assertThrows(Exception.class, () -> SpritestreamPlugin.encode(o, enc, new SpritestreamPlugin.Sprite("bad",
				new Picture("a", base), new Picture("b", shifted))));
		int[][] odd = pixels(r, 9, 5);
		assertThrows(Exception.class, () -> SpritestreamPlugin.encode(o, enc, new SpritestreamPlugin.Sprite("odd",
				new Picture("odd", odd), null)));
	}
}
