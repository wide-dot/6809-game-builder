package com.widedot.toolbox.graphics.gfxcomp.encoder;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.awt.image.BufferedImage;
import java.awt.image.IndexColorModel;
import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import com.widedot.toolbox.graphics.gfxcomp.Image;
import com.widedot.toolbox.graphics.gfxcomp.setting.VideoMemory;
import com.widedot.toolbox.graphics.gfxcomp.transformer.mirror.Mirror;

/**
 * v1's half-line tiles (Sonic 2, TILE8x16) announce when the background shows
 * through : a tile whose odd lines hold a transparent pixel opens with
 * {@code stb <glb_alphaTiles}, and the tile renderer reads the flag. The draw
 * encoder only writes it when asked ({@code alpha="odd"}) ; a sprite never
 * does. v1 counts lines from 1 : its odd lines are rows 0, 2, 4... of the
 * picture.
 */
public class DrawAlphaTest {

	private static final String FLAG = "stb   <glb_alphaTiles";

	/** an 8x16 tile ; inked on every row, or on rows 1, 3, 5... only (v1's even lines) */
	private static File tile(Path dir, String name, boolean oddLinesInked) throws Exception {
		byte[] r = new byte[17], g = new byte[17], b = new byte[17];
		for (int i = 1; i < 17; i++) { r[i] = (byte) (i * 8); g[i] = (byte) (i * 4); b[i] = (byte) (i * 2); }
		IndexColorModel cm = new IndexColorModel(8, 17, r, g, b, 0);
		BufferedImage img = new BufferedImage(8, 16, BufferedImage.TYPE_BYTE_INDEXED, cm);
		for (int y = 0; y < 16; y++)
			if (oddLinesInked || y % 2 == 1)
				for (int x = 0; x < 8; x++)
					img.getRaster().setSample(x, y, 0, 1 + (x + y) % 3);
		File file = dir.resolve(name + ".png").toFile();
		ImageIO.write(img, "png", file);
		return file;
	}

	private static String compile(Path dir, String name, boolean oddLinesInked, String alpha) throws Exception {
		VideoMemory.memoryLinearBits = 4;
		VideoMemory.memoryPlanarBits = 8;
		VideoMemory.memoryLineBytes = 40;
		VideoMemory.memoryNbPlanes = 2;
		VideoMemory.memoryPlaneDistance = 8192;
		File png = tile(dir, name, oddLinesInked);
		Image image = new Image(name, null, png.getAbsolutePath(), Image.TYPE_DRAW,
				Mirror.NONE, 0, Image.POSITION_3QTRC, Image.PLANES_POINTER);
		image.setAlphaMode(alpha);
		image.encode(dir.toString());
		return Files.readString(dir.resolve(image.getFullName() + ".asm"));
	}

	@Test
	void aHalfLineTileAnnouncesItsBackground(@TempDir Path dir) throws Exception {
		assertTrue(compile(dir, "half", false, Image.ALPHA_ODD).contains(FLAG));
	}

	@Test
	void aTileFullOnItsOddLinesDoesNot(@TempDir Path dir) throws Exception {
		assertFalse(compile(dir, "full", true, Image.ALPHA_ODD).contains(FLAG));
	}

	@Test
	void nothingIsAnnouncedByDefault(@TempDir Path dir) throws Exception {
		assertFalse(compile(dir, "sprite", false, Image.ALPHA_NONE).contains(FLAG));
	}

	@Test
	void theOptionIsTheDrawEncodersOnly(@TempDir Path dir) throws Exception {
		File png = tile(dir, "bg", false);
		Image image = new Image("bg", null, png.getAbsolutePath(), Image.TYPE_BDRAW,
				Mirror.NONE, 0, Image.POSITION_CENTER, Image.PLANES_POINTER);
		assertThrows(Exception.class, () -> image.setAlphaMode(Image.ALPHA_ODD));
	}

	@Test
	void anUnknownModeIsRefused(@TempDir Path dir) throws Exception {
		File png = tile(dir, "bg", false);
		Image image = new Image("bg", null, png.getAbsolutePath(), Image.TYPE_DRAW,
				Mirror.NONE, 0, Image.POSITION_CENTER, Image.PLANES_POINTER);
		assertThrows(Exception.class, () -> image.setAlphaMode("half"));
	}
}
