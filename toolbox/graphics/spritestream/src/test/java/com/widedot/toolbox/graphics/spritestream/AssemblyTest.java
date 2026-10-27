package com.widedot.toolbox.graphics.spritestream;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.Map;
import java.util.TreeMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import com.widedot.m6809.util.ThirdPartyTools;

/**
 * The walkers assembled with the engine's runtime by the shipped lwasm, for
 * several shape sets : the source assembles (the layout's own checks
 * included : no block runs into an aligned jump table) and every block starts
 * where the size model placed it, so the model the layout relies on is the
 * assembler's.
 */
class AssemblyTest {

	static String lwasm() {
		if (System.getProperty("lwasm.path") == null) {
			Path root = Paths.get("").toAbsolutePath();
			while (root != null && !Files.isDirectory(root.resolve("toolbox/third-party"))) {
				root = root.getParent();
			}
			assumeTrue(root != null, "repository root not found, lwasm unavailable");
			String previous = System.getProperty("basedir");
			System.setProperty("basedir", root.toString());
			String resolved = ThirdPartyTools.resolve("lwasm");
			if (previous == null) System.clearProperty("basedir");
			else System.setProperty("basedir", previous);
			assumeTrue(Files.isRegularFile(Paths.get(resolved)), "lwasm not shipped for this platform");
			System.setProperty("lwasm.path", resolved);
		}
		return ThirdPartyTools.resolve("lwasm");
	}

	static Path engine() {
		Path root = Paths.get("").toAbsolutePath();
		while (root != null && !Files.isDirectory(root.resolve("engine/graphics/sprite/stream"))) {
			root = root.getParent();
		}
		assumeTrue(root != null, "engine not found");
		return root.resolve("engine/graphics/sprite/stream/spritestream.asm");
	}

	/** assembles the walkers of o with the runtime : symbol -> value */
	static Map<String, Integer> assemble(Walker w, Path tmp) throws Exception {
		Path walker = tmp.resolve("walker.asm");
		Files.writeString(walker, w.source());
		Path src = tmp.resolve("manager.asm");
		Files.writeString(src, "map.CF74021.CART equ $E7E6\n"
				+ "dp_engine equ $9F80\n"
				+ "spritestream.dp equ $9F70\n"
				+ "spritestream.HALF equ 0\n"
				+ "spritestream.STACK equ 64\n"
				+ "        org   $4000\n"
				+ "        INCLUDE \"" + walker + "\"\n"
				+ "        INCLUDE \"" + engine() + "\"\n");
		Path out = tmp.resolve("manager.bin"), sym = tmp.resolve("manager.sym");
		Path root = engine().getParent().getParent().getParent().getParent().getParent();
		Process p = new ProcessBuilder(lwasm(), "-9", "--format=raw", "-o", out.toString(), "-I", root.toString(),
				"--symbol-dump=" + sym.toString(), src.toString()).redirectErrorStream(true).start();
		String log = new String(p.getInputStream().readAllBytes());
		assertEquals(0, p.waitFor(), "lwasm failed :\n" + log);
		Map<String, Integer> syms = new HashMap<String, Integer>();
		Pattern re = Pattern.compile("(\\S+)\\s+EQU\\s+\\$([0-9A-Fa-f]+)");
		for (String line : Files.readAllLines(sym)) {
			Matcher m = re.matcher(line);
			if (m.find()) {
				syms.put(m.group(1), (int) Long.parseLong(m.group(2), 16));
			}
		}
		return syms;
	}

	static void check(Options o, Path tmp) throws Exception {
		Walker w = new Walker(o);
		w.source();
		Map<String, Integer> syms = assemble(w, tmp);
		int at = 0x4000;
		for (Walker.Block b : w.placed) {
			for (Ins i : b.lines) {
				if (i.op == null && syms.containsKey(i.label)) {
					assertEquals(at, (int) syms.get(i.label), i.label + " (" + o.describe() + ")");
				}
				at += i.size;
			}
		}
		assertEquals(at, (int) syms.get("spritestream.walkers.end"), "the walkers' end");
	}

	@Test
	void theRecommendedSetAssembles(@TempDir Path tmp) throws Exception {
		check(PrototypeTest.reco(), tmp);
	}

	@Test
	void otherSetsAssemble(@TempDir Path tmp) throws Exception {
		Map<Integer, Integer> none = new TreeMap<Integer, Integer>();
		Map<Integer, Integer> many = new TreeMap<Integer, Integer>();
		many.put(3, 3);
		many.put(4, 2);
		Object[][] sets = {
				{ 15, none, true, true, false },     // the long segments of the first measures
				{ 8, many, true, true, false },      // 3-row records, every length
				{ 6, none, false, true, false },     // one facing
				{ 8, none, false, false, true },     // a background : no save, opaque segments
				{ 6, PrototypeTest.reco().rows, true, false, false },
				{ 4, none, true, true, true },
		};
		int k = 0;
		for (Object[] s : sets) {
			@SuppressWarnings("unchecked")
			Map<Integer, Integer> rows = (Map<Integer, Integer>) s[1];
			for (boolean merge : new boolean[] { true, false }) {
				Path dir = tmp.resolve("set" + k++);
				Files.createDirectories(dir);
				check(new Options((Integer) s[0], rows, (Boolean) s[2], (Boolean) s[3], (Boolean) s[4], merge), dir);
			}
		}
	}
}
