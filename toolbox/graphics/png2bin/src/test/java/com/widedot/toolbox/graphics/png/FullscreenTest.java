package com.widedot.toolbox.graphics.png;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.awt.image.BufferedImage;
import java.awt.image.IndexColorModel;
import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * buffer="fullscreen" : the 16 000 bytes DrawFullscreenImage copies. The
 * reference is v1's encoder, fr.bento8.to8.image.PngToBottomUpB16Bin, its loop
 * copied as it is below, run on the same pixels.
 */
public class FullscreenTest {

	@TempDir
	Path dir;

	/** a mire : every colour on every pixel phase, no symmetry (a mirror or a shifted block shows) */
	private static byte[] mire() {
		byte[] px = new byte[160 * 200];
		for (int y = 0; y < 200; y++) {
			for (int x = 0; x < 160; x++) {
				int c = (x * 7 + y * 3 + (x * y >> 5)) % 16;
				if (y < 8 && x < 24) c = 15 - (x & 15);          // a notch top left
				px[y * 160 + x] = (byte) (c + 1);                // index 1-16 : colours 0-15
			}
		}
		return px;
	}

	private File png(byte[] px, int w, int h) throws Exception {
		byte[] r = new byte[17];
		byte[] g = new byte[17];
		byte[] b = new byte[17];
		for (int i = 0; i < 17; i++) { r[i] = (byte) (i * 15); g[i] = (byte) (255 - i * 15); b[i] = (byte) (i * 7); }
		BufferedImage im = new BufferedImage(w, h, BufferedImage.TYPE_BYTE_INDEXED, new IndexColorModel(8, 17, r, g, b));
		im.getRaster().setDataElements(0, 0, w, h, px);
		File f = dir.resolve("mire.png").toFile();
		ImageIO.write(im, "png", f);
		return f;
	}

	/** v1's PngToBottomUpB16Bin, its conversion loop as it is (the declarations one a line) */
	private static byte[] v1(byte[] pixels) {
		int width = 160;
		int height = 200;
		int i;
		int j;
		byte[] pixelsAB = new byte[16000];
		for (i = (width*height)-1, j = 0; i >= 28; i -= 28) {
			pixelsAB[j]   = (byte)((pixels[i-27]-1) << 4 | (pixels[i-26]-1) & 0x0F );
			pixelsAB[j+1] = (byte)((pixels[i-23]-1) << 4 | (pixels[i-22]-1) & 0x0F );
			pixelsAB[j+2] = (byte)((pixels[i-19]-1) << 4 | (pixels[i-18]-1) & 0x0F );
			pixelsAB[j+3] = (byte)((pixels[i-15]-1) << 4 | (pixels[i-14]-1) & 0x0F );
			pixelsAB[j+4] = (byte)((pixels[i-11]-1) << 4 | (pixels[i-10]-1) & 0x0F );
			pixelsAB[j+5] = (byte)((pixels[i-7]-1)  << 4 | (pixels[i-6]-1)  & 0x0F );
			pixelsAB[j+6] = (byte)((pixels[i-3]-1)  << 4 | (pixels[i-2]-1)  & 0x0F );
			j += 8000;
			pixelsAB[j]   = (byte)((pixels[i-25]-1) << 4 | (pixels[i-24]-1) & 0x0F );
			pixelsAB[j+1] = (byte)((pixels[i-21]-1) << 4 | (pixels[i-20]-1) & 0x0F );
			pixelsAB[j+2] = (byte)((pixels[i-17]-1) << 4 | (pixels[i-16]-1) & 0x0F );
			pixelsAB[j+3] = (byte)((pixels[i-13]-1) << 4 | (pixels[i-12]-1) & 0x0F );
			pixelsAB[j+4] = (byte)((pixels[i-9]-1)  << 4 | (pixels[i-8]-1)  & 0x0F );
			pixelsAB[j+5] = (byte)((pixels[i-5]-1)  << 4 | (pixels[i-4]-1)  & 0x0F );
			pixelsAB[j+6] = (byte)((pixels[i-1]-1)  << 4 | (pixels[i]-1)    & 0x0F );
			j -= 8000;
			j += 7;
		}
		pixelsAB[j]   = (byte)((pixels[i-23]-1) << 4 | (pixels[i-22]-1) & 0x0F );
		pixelsAB[j+1] = (byte)((pixels[i-19]-1) << 4 | (pixels[i-18]-1) & 0x0F );
		pixelsAB[j+2] = (byte)((pixels[i-15]-1) << 4 | (pixels[i-14]-1) & 0x0F );
		pixelsAB[j+3] = (byte)((pixels[i-11]-1) << 4 | (pixels[i-10]-1) & 0x0F );
		pixelsAB[j+4] = (byte)((pixels[i-7]-1)  << 4 | (pixels[i-6]-1)  & 0x0F );
		pixelsAB[j+5] = (byte)((pixels[i-3]-1)  << 4 | (pixels[i-2]-1)  & 0x0F );
		j += 8000;
		pixelsAB[j]   = (byte)((pixels[i-21]-1) << 4 | (pixels[i-20]-1) & 0x0F );
		pixelsAB[j+1] = (byte)((pixels[i-17]-1) << 4 | (pixels[i-16]-1) & 0x0F );
		pixelsAB[j+2] = (byte)((pixels[i-13]-1) << 4 | (pixels[i-12]-1) & 0x0F );
		pixelsAB[j+3] = (byte)((pixels[i-9]-1)  << 4 | (pixels[i-8]-1)  & 0x0F );
		pixelsAB[j+4] = (byte)((pixels[i-5]-1)  << 4 | (pixels[i-4]-1)  & 0x0F );
		pixelsAB[j+5] = (byte)((pixels[i-1]-1)  << 4 | (pixels[i]-1)    & 0x0F );
		return pixelsAB;
	}

	private static int[] bm16() throws Exception {
		return Png2BinPlugin.mode("bm16");
	}

	private static Png2Bin fullscreen() throws Exception {
		int[] m = bm16();
		return new Png2Bin(m[0], m[1], m[2], m[3], m[4], 0, true, Png2Bin.Buffer.FULLSCREEN, 0);
	}

	@Test
	void theBytesAreV1s() throws Exception {
		byte[] px = mire();
		List<String> files = fullscreen().convert(png(px, 160, 200), dir.toString());
		byte[] out = Files.readAllBytes(Paths.get(files.get(0) + ".fullscreen"));
		assertEquals(16000, out.length);
		assertArrayEquals(v1(px), out);
	}

	@Test
	void theBanksClimbTheScreen() throws Exception {
		// the routine's first 7 bytes land at $DF39-$DF3F : the $C000 bank's last 7 bytes
		byte[] px = mire();
		List<String> files = fullscreen().convert(png(px, 160, 200), dir.toString());
		byte[] plane0 = Files.readAllBytes(Paths.get(files.get(0)));
		byte[] out = Files.readAllBytes(Paths.get(files.get(0) + ".fullscreen"));
		for (int k = 0; k < 7; k++) assertEquals(plane0[7993 + k], out[k]);
		for (int k = 0; k < 6; k++) assertEquals(plane0[k], out[7994 + k]);
	}

	@Test
	void anotherSizeIsRefused() throws Exception {
		Exception e = assertThrows(Exception.class, () -> fullscreen().convert(png(new byte[320 * 200], 320, 200), dir.toString()));
		assertTrue(e.getMessage().contains("fullscreen"), e.getMessage());
	}
}
