package com.widedot.toolbox.graphics.spritestream;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.TreeMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * The clip mode's tables against the decoder. A model of the engine's cut
 * path (spritestream.drawClip : a record's visible bytes found from its p and
 * n in the shape table, its rows and payload bytes a row in the rows table,
 * each byte's mask and data through its pair in the offsets table, mirrored
 * through the reversal) reads the tables the generator wrote, and draws every
 * stream in both facings through many clip rectangles : inside the rectangle
 * the box equals the decoder's whole walk byte for byte, outside it is
 * untouched. Also the layout the handlers rely on (the rows table 2 x CODES
 * bytes before the shape table : spritestream.ROWS ; MAXROWS), and nothing of
 * it without clip.
 */
class ClipTest {

	/** the clip tables as the generator wrote them, indexed by record code */
	static final class Tables {
		final Map<Integer, int[]> shape = new HashMap<Integer, int[]>();    // p, n
		final Map<Integer, int[]> rows = new HashMap<Integer, int[]>();     // rows, payload bytes a row
		final Map<Integer, int[]> pairs = new HashMap<Integer, int[]>();    // mask, data offsets a byte
		int rowsOffset;
		int maxRows;
	}

	static List<Integer> bytes(String arg) {
		List<Integer> out = new ArrayList<Integer>();
		for (String f : arg.split(",")) {
			out.add(Integer.parseInt(f.trim()));
		}
		return out;
	}

	static Tables tables(Walker w, Options o) {
		String src = w.source();
		Tables t = new Tables();
		Matcher m = Pattern.compile("spritestream\\.ROWS equ (-?\\d+)").matcher(src);
		assertTrue(m.find(), "spritestream.ROWS");
		t.rowsOffset = Integer.parseInt(m.group(1));
		m = Pattern.compile("spritestream\\.MAXROWS equ (\\d+)").matcher(src);
		assertTrue(m.find(), "spritestream.MAXROWS");
		t.maxRows = Integer.parseInt(m.group(1));
		Map<String, List<Integer>> offs = new HashMap<String, List<Integer>>();
		List<String> offNames = new ArrayList<String>();
		List<Integer> rowsTable = new ArrayList<Integer>(), shapeTable = new ArrayList<Integer>();
		for (Walker.Block b : w.placed) {
			if (b.name.equals("spritestream.shapes")) {
				List<Integer> cur = null;
				for (Ins i : b.lines) {
					if (i.op == null) {
						cur = i.label.equals("spritestream.shapes.rows") ? rowsTable : shapeTable;
					} else if ("fcb".equals(i.op)) {
						cur.addAll(bytes(i.arg));
					}
				}
			} else if (b.name.equals("spritestream.offsets")) {
				for (Ins i : b.lines) {
					if ("fdb".equals(i.op)) {
						for (String f : i.arg.split(",")) {
							offNames.add(f.trim());
						}
					}
				}
			} else if (b.name.startsWith("spritestream.offs.")) {
				List<Integer> v = new ArrayList<Integer>();
				for (Ins i : b.lines) {
					if ("fcb".equals(i.op)) {
						v.addAll(bytes(i.arg));
					}
				}
				offs.put(b.name, v);
			}
		}
		int codes = o.names.size();
		assertEquals(-2 * codes, t.rowsOffset, "the rows table sits 2 x CODES bytes before the shape table");
		assertEquals(2 * codes, rowsTable.size(), "rows table");
		assertEquals(2 * codes, shapeTable.size(), "shape table");
		assertEquals(codes, offNames.size(), "offsets table");
		for (int code = 4; code < 2 * codes; code += 2) {
			t.shape.put(code, new int[] { shapeTable.get(code), shapeTable.get(code + 1) });
			t.rows.put(code, new int[] { rowsTable.get(code), rowsTable.get(code + 1) });
			List<Integer> v = offs.get(offNames.get(code / 2));
			assertNotNull(v, offNames.get(code / 2));
			int[] p = new int[v.size()];
			for (int k = 0; k < p.length; k++) {
				p[k] = v.get(k);
			}
			t.pairs.put(code, p);
		}
		return t;
	}

	/** the box after a clipped walk through the tables : {mask, data} a byte, {$FF, 0} untouched */
	static int[][][] clipWalk(Options o, Tables t, byte[] s, int width, int height, boolean mirrored, int jl,
			int jr, int rt, int rb) throws Exception {
		int[][][] box = new int[height][width][];
		for (int r = 0; r < height; r++) {
			for (int j = 0; j < width; j++) {
				box[r][j] = new int[] { 0xFF, 0 };
			}
		}
		int q = (width - 1) & 1;
		int u = !mirrored && o.mirrorable ? 1 : 0;
		int y = -Walker.LINE + (mirrored ? (width - 1) >> 1 : 0);
		while (true) {
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
				return box;
			}
			if (code == o.code("nop")) {
				if (!mirrored && o.mirrorable) {
					u++;
				}
				continue;
			}
			int p = t.shape.get(code)[0], n = t.shape.get(code)[1];
			int rows = t.rows.get(code)[0], rowBytes = t.rows.get(code)[1];
			int[] pairs = t.pairs.get(code);
			int row = Math.floorDiv(y, Walker.LINE), col = Math.floorMod(y, Walker.LINE);
			int lo = mirrored ? 2 * col + (p ^ q) - n + 1 : 2 * col + p;
			for (int k = 0; k < rows; k++) {
				int r = row + k;
				if (r < rt || r >= rb) {
					continue;
				}
				for (int j = Math.max(lo, jl); j < Math.min(lo + n, jr); j++) {
					int i = mirrored ? n - 1 - (j - lo) : j - lo;
					int base = u + k * rowBytes;
					int mk = s[base + pairs[2 * i]] & 0xFF, d = s[base + pairs[2 * i + 1]] & 0xFF;
					if (mirrored) {
						mk = Picture.rev(mk);
						d = Picture.rev(d);
					}
					int[] b = box[r][j];
					box[r][j] = new int[] { b[0] & mk, (b[1] & mk) | d };
				}
			}
			u += rows * rowBytes;
			if (!mirrored && o.mirrorable) {
				u++;
			}
			if (rows >= 3) {
				y += Walker.LINE * (rows - 1);
			}
		}
	}

	/** a byte's effect on a screen byte, (s AND mask) OR data, told by its values at $00 and $FF */
	static int effect(int[] b) {
		return (b[1] << 8) | ((0xFF & b[0]) | b[1]);
	}

	/** every column window and a few row windows : the clipped walk against the decoder's */
	static int check(Options o, Tables t, byte[] s, int width, int height, String what) throws Exception {
		int n = 0;
		for (boolean mirrored : o.mirrorable ? new boolean[] { false, true } : new boolean[] { false }) {
			int[][][] whole = Decoder.walk(o, s, width, height, mirrored);
			int[][] rws = { { 0, height }, { 1, height }, { 0, height - 1 }, { height / 2, height },
					{ 0, height / 2 }, { height / 3, height - height / 3 } };
			for (int jl = 0; jl < width; jl++) {
				for (int jr = jl + 1; jr <= width; jr++) {
					for (int[] rw : rws) {
						if (rw[0] >= rw[1]) {
							continue;
						}
						int[][][] got = clipWalk(o, t, s, width, height, mirrored, jl, jr, rw[0], rw[1]);
						for (int r = 0; r < height; r++) {
							for (int j = 0; j < width; j++) {
								boolean in = r >= rw[0] && r < rw[1] && j >= jl && j < jr;
								int want = effect(in ? whole[r][j] : new int[] { 0xFF, 0 });
								assertEquals(want, effect(got[r][j]), what + (mirrored ? " mirrored" : "") + " clip ["
										+ jl + "," + jr + ")x[" + rw[0] + "," + rw[1] + ") row " + r + " byte " + j);
							}
						}
						n++;
					}
				}
			}
		}
		return n;
	}

	@Test
	void theMiresStreamsClipExactly(@TempDir Path tmp) throws Exception {
		Options o = PrototypeTest.reco(true);
		Walker w = new Walker(o);
		Tables t = tables(w, o);
		assertEquals(2, t.maxRows);
		Encoder enc = new Encoder(o);
		int pictures = 0, walks = 0;
		for (String line : PrototypeTest.resource("streams.txt").split("\n")) {
			if (line.isBlank()) {
				continue;
			}
			Picture p = PrototypeTest.picture(line.split(" ")[0], tmp);
			byte[] s = enc.stream(p.bytes);
			walks += check(o, t, s, p.bytes[0].length, p.bytes.length, p.file);
			pictures++;
		}
		assertEquals(96, pictures);
		assertTrue(walks > 96 * 2 * 6, "every column window of every picture");
	}

	@Test
	void otherSetsClipExactly() throws Exception {
		Random r = new Random(1984);
		Map<Integer, Integer> rows = new TreeMap<Integer, Integer>();
		rows.put(2, 3);
		rows.put(3, 4);
		Map<Integer, Integer> none = new TreeMap<Integer, Integer>();
		Options[] sets = {
				new Options(6, rows, true, true, false, true, true),   // 3 and 4 row records : the walk advances
				new Options(4, rows, true, true, true, false, true),   // opaque segments
				new Options(8, none, false, true, false, true, true),  // one facing
				new Options(1, none, true, false, false, true, true),  // single bytes, no save
		};
		for (Options o : sets) {
			Walker w = new Walker(o);
			Tables t = tables(w, o);
			Encoder enc = new Encoder(o);
			for (int k = 0; k < 12; k++) {
				int wd = 2 * (1 + r.nextInt(12)), h = 1 + r.nextInt(24);
				Picture p = new Picture("random" + k, EncoderTest.pixels(r, wd, h));
				check(o, t, enc.stream(p.bytes), p.bytes[0].length, p.bytes.length, o.describe() + " " + p.file);
			}
		}
	}

	@Test
	void onlyTheClipModePaysForIt() throws Exception {
		Map<Integer, Integer> none = new TreeMap<Integer, Integer>();
		String clip = new Walker(new Options(6, none, true, true, false, true, true)).source();
		assertTrue(clip.contains("spritestream.RCLIP equ") && clip.contains("spritestream.RBYTE equ")
				&& clip.contains("spritestream.shapes"), "clip tables");
		String plain = new Walker(new Options(6, none, true, true, false, true, false)).source();
		assertTrue(!plain.contains("RCLIP") && !plain.contains("spritestream.shapes") && !plain.contains("clipStored"),
				"no clip : no clip tables, no handler in the jump tables");
	}
}
