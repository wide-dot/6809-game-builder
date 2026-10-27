package com.widedot.toolbox.graphics.spritestream;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * Byte for byte against the reference the generator reproduces : the M4
 * prototype that measured the shape sets (a game's bench, Python), its
 * recommended set (segment 6, 2-row records of 2 and 3 bytes, mirrorable,
 * save, merged pulls). The references in src/test/resources/prototype were
 * written by that prototype from a seeded mire (48 pictures, each at both
 * 2 pixel steps : silhouettes, repeated rows, sparse rows with gaps, noise) :
 * {@code streams.txt} (picture, stream in hex) and {@code walkers.asm} (its
 * walkers and restore routines, labels WSN/WSM/WR).
 */
class PrototypeTest {

	static Options reco() throws Exception {
		Map<Integer, Integer> rows = new TreeMap<Integer, Integer>();
		rows.put(2, 2);
		rows.put(3, 2);
		return new Options(6, rows, true, true, false, true);
	}

	static String resource(String name) throws Exception {
		try (InputStream in = PrototypeTest.class.getResourceAsStream("/prototype/" + name)) {
			assertNotNull(in, name);
			return new String(in.readAllBytes(), StandardCharsets.UTF_8);
		}
	}

	static Picture picture(String name, Path tmp) throws Exception {
		Path p = tmp.resolve(name);
		try (InputStream in = PrototypeTest.class.getResourceAsStream("/prototype/" + name)) {
			Files.copy(in, p);
		}
		return Picture.read(p.toString());
	}

	static String hex(byte[] b) {
		StringBuilder sb = new StringBuilder();
		for (byte x : b) {
			sb.append(String.format("%02x", x & 0xFF));
		}
		return sb.toString();
	}

	@Test
	void theStreamsAreThePrototypes(@TempDir Path tmp) throws Exception {
		Options o = reco();
		Encoder enc = new Encoder(o);
		int n = 0;
		for (String line : resource("streams.txt").split("\n")) {
			if (line.isBlank()) {
				continue;
			}
			String[] f = line.split(" ");
			Picture p = picture(f[0], tmp);
			byte[] s = enc.stream(p.bytes);
			assertEquals(f[1], hex(s), f[0]);
			Decoder.check(o, s, p.bytes, false, f[0]);
			Decoder.check(o, s, p.bytes, true, f[0]);
			n++;
		}
		assertEquals(96, n);
	}

	/** routines by label, their instructions normalised (one space, the prototype's names mapped) */
	static Map<String, List<String>> routines(String source, boolean prototype) {
		Map<String, List<String>> out = new LinkedHashMap<String, List<String>>();
		List<String> cur = null;
		for (String raw : source.split("\n")) {
			String line = raw.replaceAll(";.*", "").stripTrailing();
			if (line.isBlank() || line.startsWith("*")) {
				continue;
			}
			if (!Character.isWhitespace(line.charAt(0))) {
				String[] f = line.trim().split("\\s+");
				String label = prototype ? map(f[0]) : f[0];
				if (f.length > 1) {
					cur = null;                         // an equate or a labelled data line
					continue;
				}
				cur = new ArrayList<String>();
				out.put(label, cur);
				continue;
			}
			if (cur != null) {
				String[] f = line.trim().split("\\s+", 2);
				if (java.util.Set.of("rmb", "ifgt", "error", "endc", "fcb", "fdb").contains(f[0])) {
					continue;                           // layout and data lines
				}
				String arg = f.length > 1 ? f[1].trim() : "";
				if (prototype) {
					arg = arg.replace("<m.saveS", "<spritestream.saveS").replace("<m4.top", "<spritestream.top")
							.replace("<m4.jtk", "<spritestream.jtk").replace("#WR.jt", "#spritestream.wr.jt");
					arg = map(arg);
				}
				cur.add(f[0] + " " + arg);
			}
		}
		return out;
	}

	static String map(String s) {
		return s.replace("WSN.", "spritestream.wn.").replace("WSM.", "spritestream.wm.")
				.replace("WR.restore", "spritestream.restore").replace("WR.", "spritestream.wr.")
				.replace("m4.jtn", "spritestream.jtn");
	}

	@Test
	void theWalkersAreThePrototypes() throws Exception {
		Map<String, List<String>> want = routines(resource("walkers.asm"), true);
		Map<String, List<String>> got = routines(new Walker(reco()).source(), false);
		int compared = 0;
		for (Map.Entry<String, List<String>> e : want.entrySet()) {
			String label = e.getKey();
			if (label.startsWith("rev.") || label.contains(".jt") || label.equals("spritestream.wr.jt")) {
				continue;                               // tables : compared below
			}
			assertTrue(got.containsKey(label), "no routine " + label);
			assertEquals(e.getValue(), got.get(label), label);
			compared++;
		}
		// 2 x 16 shapes x 2 facings, draw / nop / end x 2, restore + end + 59 pull sequences
		assertEquals(64 + 6 + 61, compared);
	}

	/** fdb entries of a table, by its label */
	static Map<String, List<String>> tables(String source, boolean prototype) {
		Map<String, List<String>> out = new HashMap<String, List<String>>();
		List<String> cur = null;
		for (String raw : source.split("\n")) {
			String line = raw.stripTrailing();
			if (line.isBlank() || line.startsWith("*")) {
				continue;
			}
			if (!Character.isWhitespace(line.charAt(0))) {
				String label = line.trim().split("\\s+")[0];
				label = prototype ? map(label).replace("spritestream.wm.jt", "spritestream.jtm") : label;
				cur = new ArrayList<String>();
				out.put(label, cur);
				continue;
			}
			String[] f = line.trim().split("\\s+", 2);
			if (cur != null && "fdb".equals(f[0])) {
				cur.add(prototype ? map(f[1]) : f[1]);
			}
		}
		return out;
	}

	@Test
	void theJumpTablesAreThePrototypes() throws Exception {
		Map<String, List<String>> want = tables(resource("walkers.asm"), true);
		Map<String, List<String>> got = tables(new Walker(reco()).source(), false);
		for (String t : new String[] { "spritestream.jtn0", "spritestream.jtn1", "spritestream.jtm1",
				"spritestream.jtm2", "spritestream.jtm3", "spritestream.jtm4", "spritestream.wr.jt" }) {
			assertEquals(want.get(t), got.get(t), t);
		}
	}
}
