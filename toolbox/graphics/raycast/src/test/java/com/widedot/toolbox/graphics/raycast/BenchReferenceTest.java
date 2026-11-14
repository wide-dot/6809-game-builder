package com.widedot.toolbox.graphics.raycast;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;

/**
 * examples/wallscaler's bench reference (bench.ref : what the 6809 code
 * summed under toje, per camera its column descriptors and the view of the
 * screen, then the screen outside the view) against the same sums made from
 * the model, for the example's three targets.
 */
class BenchReferenceTest {

	/** where the example's config places the textures */
	static final int TEXTURES = 0x7800;
	static final int CEIL = 0x11;
	static final int FLOOR = 0x22;

	/** the bench's sum : rotated left by a bit, plus the byte */
	static int add(int sum, int b) {
		int rotated = ((sum << 1) | (sum >>> 15)) & 0xFFFF;
		return (rotated + (b & 0xFF)) & 0xFFFF;
	}

	/** the bench's cameras, from the game mode's table : x, y, angle */
	static List<int[]> cameras(Path example) throws Exception {
		List<int[]> cams = new ArrayList<int[]>();
		boolean in = false;
		for (String l : Files.readAllLines(example.resolve("src/main.asm"))) {
			if (l.startsWith("bench.cameras.end")) {
				break;
			}
			if (in && l.trim().startsWith("fdb")) {
				String[] v = l.trim().substring(3).trim().split(",");
				cams.add(new int[] { Integer.parseInt(v[0].trim()), Integer.parseInt(v[1].trim()),
						Integer.parseInt(v[2].trim()) });
			}
			in |= l.startsWith("bench.cameras");
		}
		return cams;
	}

	static List<String> model(String disk, Geometry g, boolean pair, Path example) throws Exception {
		TextureEncoder tex = TextureEncoder.read(example.resolve("src/textures.png").toString());
		byte[] texels = tex.bytes();
		GridMap map = GridMap.read(example.resolve("src/map.png").toString(), tex.count());
		RayModel model = new RayModel(new RayTables(g), map, pair);
		List<String> lines = new ArrayList<String>();
		int test = 1;
		for (int[] cam : cameras(example)) {
			RayModel.Frame f = model.frame(cam[0], cam[1], cam[2], TEXTURES);
			int sum = 0;
			for (int k = 0; k < g.cols; k++) {
				sum = add(sum, Math.max(0, g.topRow(f.samples[k] * g.unit())));
				sum = add(sum, f.texture[k] >> 8);
				sum = add(sum, f.texture[k]);
			}
			lines.add(String.format("%s t%02d 01 %04X", disk, test++, sum));
			sum = 0;
			// the $A000 bank holds the odd columns, the $C000 bank the even ones
			for (int bank = 1; bank >= 0; bank--) {
				for (int y = 0; y < g.rows; y++) {
					for (int k = bank; k < g.cols; k += 2) {
						int h = f.samples[k] * g.unit();
						int t = g.topRow(h);
						int b = y < g.rows / 2 ? CEIL : FLOOR;
						if (y >= t && y < t + h) {
							b = texels[f.texture[k] - TEXTURES + g.texelRows(h)[y - t]];
						}
						sum = add(sum, b);
					}
				}
			}
			lines.add(String.format("%s t%02d 01 %04X", disk, test++, sum));
		}
		// outside the view : the game's test card, a byte the two halves of its address
		int sum = 0;
		for (int base : new int[] { 0xA000, 0xC000 }) {
			for (int y = 0; y < 200; y++) {
				for (int k = 0; k < 40; k++) {
					boolean in = y >= g.y && y < g.y + g.rows && k >= g.x / 2 && k < (g.x + g.cols) / 2;
					if (!in) {
						int addr = base + y * 40 + k;
						sum = add(sum, (addr & 0xFF) ^ (addr >> 8));
					}
				}
			}
		}
		lines.add(String.format("%s t%02d 01 %04X", disk, test, sum));
		return lines;
	}

	@Test
	void theMachineSumsWhatTheModelSums() throws Exception {
		Path root = Views.root();
		assumeTrue(root != null);
		Path example = root.resolve("examples/wallscaler");
		Path ref = example.resolve("bench.ref");
		assumeTrue(Files.isRegularFile(ref), "the example's reference is not there");
		List<String> exp = new ArrayList<String>();
		exp.addAll(model("to8", Views.whole(), true, example));
		exp.addAll(model("to8-view", Views.small(), true, example));
		exp.addAll(model("to8-fine", Views.fine(), false, example));
		List<String> got = Files.readAllLines(ref);
		assertEquals(exp.size(), got.size(), "tests");
		for (int i = 0; i < exp.size(); i++) {
			assertEquals(exp.get(i), got.get(i));
		}
	}
}
