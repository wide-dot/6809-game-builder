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
 * The center-w2 anchor : column w/2 and row h/2, where center takes (w-1)/2
 * and (h-1)/2. The ink offsets are measured from the anchor, so a pixel at a
 * known place of the canvas gives the anchor away.
 */
public class CenterW2Test {

	/** an 8 bit indexed w x h canvas, colour 0 transparent, one pixel of colour 1 at (x, y) */
	private static File canvas(Path dir, String name, int w, int h, int x, int y) throws Exception {
		byte[] r = new byte[17];
		byte[] g = new byte[17];
		byte[] b = new byte[17];
		for (int i = 1; i < 17; i++) { r[i] = (byte) (i * 8); g[i] = (byte) (i * 4); b[i] = (byte) (i * 2); }
		IndexColorModel cm = new IndexColorModel(8, 17, r, g, b, 0);
		BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_BYTE_INDEXED, cm);
		img.getRaster().setSample(x, y, 0, 1);
		File file = dir.resolve(name + ".png").toFile();
		ImageIO.write(img, "png", file);
		return file;
	}

	private static Image image(File png, String mirror, String position) throws Exception {
		return new Image("img", null, png.getAbsolutePath(), Image.TYPE_DRAW, mirror, 0, position);
	}

	@Test
	void evenSizeAnchorsOnTheHalves(@TempDir Path dir) throws Exception {
		// 30x40, the pixel at (15, 20) : the anchor itself under center-w2,
		// one right of and one under the center anchor (14, 19)
		File png = canvas(dir, "even", 30, 40, 15, 20);
		Image center = image(png, Mirror.NONE, Image.POSITION_CENTER);
		Image w2 = image(png, Mirror.NONE, Image.POSITION_CENTER_W2);
		assertEquals(1, center.getSubImageX1Offset());
		assertEquals(1, center.getSubImageY1Offset());
		assertEquals(0, w2.getSubImageX1Offset());
		assertEquals(0, w2.getSubImageY1Offset());
		// the runtime's parity byte follows the anchor : 15 - 4*(30/8) = 3
		assertEquals(3, w2.getCenterOffset());
		assertEquals(2, center.getCenterOffset());
	}

	@Test
	void oddSizeIsTheCenterAnchor(@TempDir Path dir) throws Exception {
		File png = canvas(dir, "odd", 31, 41, 15, 20);
		Image center = image(png, Mirror.NONE, Image.POSITION_CENTER);
		Image w2 = image(png, Mirror.NONE, Image.POSITION_CENTER_W2);
		assertEquals(center.getSubImageX1Offset(), w2.getSubImageX1Offset());
		assertEquals(center.getSubImageY1Offset(), w2.getSubImageY1Offset());
		assertEquals(center.getCenterOffset(), w2.getCenterOffset());
		assertEquals(center.getCoordinate(), w2.getCoordinate());
	}

	@Test
	void fullScreenCanvas(@TempDir Path dir) throws Exception {
		// a 160x200 screen-size canvas : the anchor (80, 100), its top-left
		// pixel at (-80, -100), no room needed past the screen
		File png = canvas(dir, "screen", 160, 200, 0, 0);
		Image w2 = image(png, Mirror.NONE, Image.POSITION_CENTER_W2);
		assertEquals(-80, w2.getSubImageX1Offset());
		assertEquals(-100, w2.getSubImageY1Offset());
		assertEquals(100 * 40 + 20, w2.getCoordinate());
	}

	@Test
	void mirrorFlipsAroundTheOrigin(@TempDir Path dir) throws Exception {
		// the Mega Drive flips dx to -1-dx : the pixel just right of the
		// origin (dx 0) lands just left of it (dx -1), same for the rows
		File png = canvas(dir, "flip", 30, 40, 15, 20);
		assertEquals(-1, image(png, Mirror.X, Image.POSITION_CENTER_W2).getSubImageX1Offset());
		assertEquals(0, image(png, Mirror.X, Image.POSITION_CENTER_W2).getSubImageY1Offset());
		assertEquals(0, image(png, Mirror.Y, Image.POSITION_CENTER_W2).getSubImageX1Offset());
		assertEquals(-1, image(png, Mirror.Y, Image.POSITION_CENTER_W2).getSubImageY1Offset());
		assertEquals(-1, image(png, Mirror.XY, Image.POSITION_CENTER_W2).getSubImageX1Offset());
		assertEquals(-1, image(png, Mirror.XY, Image.POSITION_CENTER_W2).getSubImageY1Offset());
	}
}
