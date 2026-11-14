package com.widedot.toolbox.graphics.raycast;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import com.widedot.m6809.util.ThirdPartyTools;

/**
 * Every routine run by an interpreter of its few instructions : it writes
 * the wall's rows of the view, each with the texel the geometry gives it,
 * and nothing else. Then the routines assembled by the shipped lwasm : each
 * starts where the size model placed it.
 */
class ScalerTest {

	static final Geometry[] VIEWS = { Views.whole(), Views.small(), Views.fine(),
			new Geometry(40, 96, 20, 52, 4, 16, 192, 90, 1.0) };

	static final Pattern INS = Pattern.compile("\\s+(\\w+)\\s+(-?\\d+)?,([xu])");

	/** the column a routine draws : per view row the texel written, -1 none */
	static int[] run(Geometry g, ScalerGen.Routine r) {
		int[] col = new int[g.rows];
		Arrays.fill(col, -1);
		int u = 0;
		int a = -1;
		int b = -1;
		for (String line : r.lines) {
			if (line.trim().equals("rts")) {
				continue;
			}
			Matcher m = INS.matcher(line);
			assertTrue(m.matches(), "unknown instruction : " + line);
			int off = m.group(2) == null ? 0 : Integer.parseInt(m.group(2));
			String op = m.group(1);
			if (op.equals("leau")) {
				u += off;
			} else if (op.equals("lda")) {
				a = off;
			} else if (op.equals("ldd")) {
				a = off;
				b = off + 1;
			} else {
				assertTrue(op.equals("sta") || op.equals("stb"), line);
				assertTrue(off >= -128 && off <= 127, "an offset out of 8 bits : " + line);
				int at = u + off;
				assertEquals(0, Math.floorMod(at, Geometry.STRIDE), "a write off the column : " + line);
				int row = at / Geometry.STRIDE;
				assertTrue(row >= 0 && row < g.rows, "a write out of the view, row " + row);
				assertEquals(-1, col[row], "row " + row + " written twice");
				col[row] = op.equals("sta") ? a : b;
			}
		}
		return col;
	}

	@Test
	void everyRoutineDrawsItsWall() {
		for (Geometry g : VIEWS) {
			ScalerGen gen = new ScalerGen(g);
			for (int h : g.heights()) {
				int[] col = run(g, gen.routine(h));
				int t = g.topRow(h);
				int[] texel = g.texelRows(h);
				for (int y = 0; y < g.rows; y++) {
					int exp = y >= t && y < t + h ? texel[y - t] : -1;
					assertEquals(exp, col[y], "height " + h + ", row " + y + " (view " + g.cols + "x" + g.rows + ")");
				}
				assertTrue(texel[texel.length - 1] < Geometry.TEX, "height " + h + " reads past the texture");
			}
		}
	}

	@Test
	void everyHeightSnapsToARoutine() {
		for (Geometry g : VIEWS) {
			int[] snap = g.snap();
			for (int n = 1; n < snap.length; n++) {
				assertTrue(g.heights().contains(snap[n] * g.unit()), n + " samples snap to " + snap[n]);
			}
			RayTables t = new RayTables(g);
			for (int n : t.nsamp) {
				assertTrue(n >= 1 && n <= g.indexMax() && snap[n] == n, "the samples table gives " + n);
			}
		}
	}

	@Test
	void sizesAreTheAssemblers(@TempDir Path tmp) throws Exception {
		Path root = Views.root();
		assumeTrue(root != null, "repository root not found, lwasm unavailable");
		String previous = System.getProperty("basedir");
		System.setProperty("basedir", root.toString());
		String lwasm = ThirdPartyTools.resolve("lwasm");
		if (previous == null) {
			System.clearProperty("basedir");
		} else {
			System.setProperty("basedir", previous);
		}
		assumeTrue(Files.isRegularFile(Paths.get(lwasm)), "lwasm not shipped for this platform");
		for (Geometry g : VIEWS) {
			ScalerGen gen = new ScalerGen(g);
			StringBuilder all = new StringBuilder(" ORG $0000\n");
			Map<String, Integer> model = new HashMap<String, Integer>();
			int at = 0;
			for (int h : g.heights()) {
				ScalerGen.Routine r = gen.routine(h);
				all.append(Sources.routine(r));
				model.put(Sources.scaler(h), at);
				at += r.size;
			}
			all.append("scalers.end\n");
			model.put("scalers.end", at);
			Path src = tmp.resolve("scalers.asm");
			Path sym = tmp.resolve("scalers.sym");
			Files.writeString(src, all.toString());
			Process proc = new ProcessBuilder(lwasm, "-9", "--format=raw", "-o", tmp.resolve("scalers.bin").toString(),
					"--symbol-dump=" + sym, src.toString()).redirectErrorStream(true).start();
			String log = new String(proc.getInputStream().readAllBytes());
			assertEquals(0, proc.waitFor(), "lwasm failed :\n" + log);
			Pattern re = Pattern.compile("(\\S+)\\s+EQU\\s+\\$([0-9A-Fa-f]+)");
			int seen = 0;
			for (String line : Files.readAllLines(sym)) {
				Matcher m = re.matcher(line);
				if (m.find() && model.containsKey(m.group(1))) {
					assertEquals(model.get(m.group(1)), (int) Long.parseLong(m.group(2), 16), m.group(1));
					seen++;
				}
			}
			assertEquals(model.size(), seen, "every routine in the symbols");
		}
	}
}
