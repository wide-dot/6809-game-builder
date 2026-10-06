package com.widedot.toolbox.graphics.gfxcomp;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.awt.image.BufferedImage;
import java.awt.image.IndexColorModel;
import java.io.File;
import java.nio.file.Path;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import com.widedot.toolbox.graphics.gfxcomp.transformer.mirror.Mirror;

/**
 * The halfline option keeps the rows at an even distance from the anchor
 * row, after the mirror : every mirror of an image keeps the same rows
 * around its anchor.
 */
public class HalflineTest {

	/** an 8 bit indexed 8x8 canvas, colour 1 on rows y0 to y1 */
	private static File rows(Path dir, int y0, int y1) throws Exception {
		byte[] r = new byte[17];
		byte[] g = new byte[17];
		byte[] b = new byte[17];
		for (int i = 1; i < 17; i++) { r[i] = (byte) (i * 8); g[i] = (byte) (i * 4); b[i] = (byte) (i * 2); }
		IndexColorModel cm = new IndexColorModel(8, 17, r, g, b, 0);
		BufferedImage img = new BufferedImage(8, 8, BufferedImage.TYPE_BYTE_INDEXED, cm);
		for (int y = y0; y <= y1; y++)
			for (int x = 0; x < 8; x++)
				img.getRaster().setSample(x, y, 0, 1);
		File file = dir.resolve("rows" + y0 + y1 + ".png").toFile();
		ImageIO.write(img, "png", file);
		return file;
	}

	private static Image image(File png, String mirror, boolean halfline) throws Exception {
		return new Image("img", null, png.getAbsolutePath(), Image.TYPE_DRAW, mirror, 0,
				Image.POSITION_CENTER_W2, Image.PLANES_POINTER, halfline);
	}

	@Test
	void keepsTheRowsAtAnEvenDistanceFromTheAnchor(@TempDir Path dir) throws Exception {
		// rows 3 to 6 inked, the anchor row 4 : rows 4 and 6 stay
		File png = rows(dir, 3, 6);
		assertEquals(-1, image(png, Mirror.NONE, false).getSubImageY1Offset());
		assertEquals(0, image(png, Mirror.NONE, true).getSubImageY1Offset());
		assertEquals(2, image(png, Mirror.NONE, true).getSubImageYSize());
	}

	@Test
	void theMirrorKeepsTheSameRows(@TempDir Path dir) throws Exception {
		// flipped, rows 3 to 6 become 1 to 4 : rows 2 and 4 stay
		File png = rows(dir, 3, 6);
		assertEquals(-2, image(png, Mirror.Y, true).getSubImageY1Offset());
		assertEquals(2, image(png, Mirror.Y, true).getSubImageYSize());
	}
}
