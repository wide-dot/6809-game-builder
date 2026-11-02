package com.widedot.toolbox.graphics.png2pal;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * format="rgb12" with lift and darkest="black" : v1 Another World's palette
 * conversion. The reference (src/test/resources/rgb12-mire.ref) is that
 * conversion's code as it was, run by gen_rgb12_reference.py on a mire of 256
 * palettes holding the 4096 colours.
 */
public class Rgb12Test {

	@TempDir
	Path dir;

	private static Path resource(String name) throws Exception {
		return Paths.get(Rgb12Test.class.getResource("/" + name).toURI());
	}

	private byte[] convert(Png2PalPlugin.Options o, int palettes) throws Exception {
		o.format = "rgb12";
		o.palettes = palettes;
		String out = dir.resolve("out.bin").toString();
		return Png2PalPlugin.run(null, Png2PalPlugin.BIN, 16, 1, "to", resource("rgb12-mire.bin").toString(), out, "code", o);
	}

	@Test
	void theLevelsAreV1s() throws Exception {
		Png2PalPlugin.Options o = new Png2PalPlugin.Options();
		o.lift = new double[] {5, 15, 42};
		o.darkestBlack = true;
		byte[] got = convert(o, 256);
		byte[] ref = Files.readAllBytes(resource("rgb12-mire.ref"));
		int differ = 0;
		for (int i = 0; i < ref.length; i += 2) {
			if (got[i] != ref[i] || got[i + 1] != ref[i + 1]) differ++;
		}
		assertEquals(0, differ, differ + " colours of 4096 differ from v1's");
		assertArrayEquals(ref, got);
	}

	@Test
	void theWordsAreRead() throws Exception {
		// $0RGB : component c is c * 17
		byte[] words = Files.readAllBytes(resource("rgb12-mire.bin"));
		int w = (words[2] & 0xFF) << 8 | words[3] & 0xFF;
		java.awt.Color c = Png2PalPlugin.rgb12(resource("rgb12-mire.bin").toFile(), 16, 1).get(1);
		assertEquals(((w >> 8) & 15) * 17, c.getRed());
		assertEquals(((w >> 4) & 15) * 17, c.getGreen());
		assertEquals((w & 15) * 17, c.getBlue());
	}

	@Test
	void aShortFileIsRefused() throws Exception {
		Exception e = assertThrows(Exception.class, () -> convert(new Png2PalPlugin.Options(), 257));
		assertTrue(e.getMessage().contains("257 palettes"), e.getMessage());
	}

	@Test
	void theDarkestIsBlack() throws Exception {
		Png2PalPlugin.Options o = new Png2PalPlugin.Options();
		o.darkestBlack = true;
		byte[] got = convert(o, 256);
		File src = resource("rgb12-mire.bin").toFile();
		java.util.List<java.awt.Color> cs = Png2PalPlugin.rgb12(src, 16, 256);
		for (int p = 0; p < 256; p++) {
			int dark = p * 16;
			for (int i = p * 16; i < p * 16 + 16; i++) {
				java.awt.Color a = cs.get(i);
				java.awt.Color b = cs.get(dark);
				if (Conversion.lab(a.getRed(), a.getGreen(), a.getBlue())[0] < Conversion.lab(b.getRed(), b.getGreen(), b.getBlue())[0]) dark = i;
			}
			assertEquals(0, got[2 * dark], "palette " + p);
			assertEquals(0, got[2 * dark + 1], "palette " + p);
		}
	}

	@Test
	void theZerosAreKept() throws Exception {
		// zeros="keep" : the search's levels, a component at 0 in the colour set to 0
		Png2PalPlugin.Options o = new Png2PalPlugin.Options();
		o.lift = new double[] {5, 15, 42};
		o.darkestBlack = true;
		byte[] free = convert(o, 256);
		o.keepZeros = true;
		byte[] got = convert(o, 256);
		java.util.List<java.awt.Color> cs = Png2PalPlugin.rgb12(resource("rgb12-mire.bin").toFile(), 16, 256);
		int changed = 0;
		for (int i = 0; i < cs.size(); i++) {
			java.awt.Color c = cs.get(i);
			int g = (free[2 * i] >> 4) & 15, r = free[2 * i] & 15, b = free[2 * i + 1] & 15;   // GGGGRRRR, 0000BBBB
			int want = (c.getGreen() == 0 ? 0 : g) << 4 | (c.getRed() == 0 ? 0 : r);
			assertEquals(want, got[2 * i] & 0xFF, "colour " + i);
			assertEquals(c.getBlue() == 0 ? 0 : b, got[2 * i + 1], "colour " + i);
			if (got[2 * i] != free[2 * i] || got[2 * i + 1] != free[2 * i + 1]) changed++;
		}
		assertTrue(changed > 0, "the mire has colours with a component at 0 the search lifts");
	}

	@Test
	void anUnknownZerosIsRefused() {
		Exception e = assertThrows(Exception.class, () -> Png2PalPlugin.keepZeros("black"));
		assertTrue(e.getMessage().contains("[search, keep]"), e.getMessage());
	}

	@Test
	void theColoursAreKeptApart() throws Exception {
		// apart="6" : a colour the option moved is, from every darker colour of its palette, at
		// least their original distance (6 at most) ; the others are the search's
		Png2PalPlugin.Options o = new Png2PalPlugin.Options();
		o.lift = new double[] {5, 15, 42};
		o.darkestBlack = true;
		o.keepZeros = true;
		byte[] free = convert(o, 256);
		o.apart = 6;
		byte[] got = convert(o, 256);
		java.util.List<java.awt.Color> cs = Png2PalPlugin.rgb12(resource("rgb12-mire.bin").toFile(), 16, 256);
		int[] lv = {0, 97, 122, 143, 158, 171, 184, 194, 204, 212, 219, 227, 235, 242, 250, 255};
		int moved = 0;
		for (int p = 0; p < 256; p++) {
			for (int j = p * 16; j < p * 16 + 16; j++) {
				if (got[2 * j] == free[2 * j] && got[2 * j + 1] == free[2 * j + 1]) {
					continue;
				}
				moved++;
				java.awt.Color c = cs.get(j);
				double[] lc = Conversion.lab(c.getRed(), c.getGreen(), c.getBlue());
				double[] lt = Conversion.lab(lv[got[2 * j] & 15], lv[(got[2 * j] >> 4) & 15], lv[got[2 * j + 1] & 15]);
				for (int k = p * 16; k < p * 16 + 16; k++) {
					java.awt.Color d = cs.get(k);
					double[] ld = Conversion.lab(d.getRed(), d.getGreen(), d.getBlue());
					if (k == j || d.equals(c) || ld[0] > lc[0] || ld[0] == lc[0] && k > j) {
						continue;                          // the darker ones only : placed before
					}
					double want = Math.min(Conversion.ciede2000(lc, ld), 6);
					double[] lk = Conversion.lab(lv[got[2 * k] & 15], lv[(got[2 * k] >> 4) & 15], lv[got[2 * k + 1] & 15]);
					assertTrue(Conversion.ciede2000(lt, lk) >= want, "palette " + p + " colours " + j + ", " + k);
				}
			}
		}
		assertTrue(moved > 0, "the mire has colours the search brings together");
	}

	@Test
	void aBadApartIsRefused() {
		assertThrows(Exception.class, () -> Png2PalPlugin.apart("far"));
		Exception e = assertThrows(Exception.class, () -> Png2PalPlugin.apart("0"));
		assertTrue(e.getMessage().contains("above 0"), e.getMessage());
	}
}
