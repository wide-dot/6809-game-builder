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
}
