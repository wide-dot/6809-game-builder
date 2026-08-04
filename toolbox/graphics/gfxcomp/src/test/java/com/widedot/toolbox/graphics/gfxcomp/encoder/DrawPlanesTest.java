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
 * A drawing routine reaches the two video planes one of two ways, and the
 * choice is the caller's, not the image's.
 *
 * The historical form points at the second plane through
 * {@code glb_screen_location_1} and consumes U walking the first : right for a
 * sprite drawn once at a computed position. It is wrong for a caller that
 * draws a ROW of them — a HUD advancing U by one byte between digits — which
 * is why v1's HUD hand-wrote its twelve digits instead of generating them.
 */
public class DrawPlanesTest {

	/** an 8 bit indexed sprite, colour 0 transparent, a 2x2 block of colour 1 */
	private static File sprite(Path dir, String name) throws Exception {
		byte[] r = new byte[17], g = new byte[17], b = new byte[17];
		for (int i = 1; i < 17; i++) { r[i] = (byte) (i * 8); g[i] = (byte) (i * 4); b[i] = (byte) (i * 2); }
		IndexColorModel cm = new IndexColorModel(8, 17, r, g, b, 0);
		BufferedImage img = new BufferedImage(8, 8, BufferedImage.TYPE_BYTE_INDEXED, cm);
		for (int y = 3; y < 5; y++)
			for (int x = 3; x < 5; x++)
				img.getRaster().setSample(x, y, 0, 1);

		File file = dir.resolve(name + ".png").toFile();
		ImageIO.write(img, "png", file);
		return file;
	}

	private static String compile(Path dir, String name, String planes) throws Exception {
		VideoMemory.memoryLinearBits = 4;
		VideoMemory.memoryPlanarBits = 8;
		VideoMemory.memoryLineBytes = 40;
		VideoMemory.memoryNbPlanes = 2;
		VideoMemory.memoryPlaneDistance = 8192;

		File png = sprite(dir, name);
		Image image = new Image(name, 0, png.getAbsolutePath(), Image.TYPE_DRAW,
				Mirror.NONE, 0, Image.POSITION_CENTER, planes);
		image.encode(dir.toString());
		return Files.readString(dir.resolve(image.getFullName() + ".asm"));
	}

	@Test
	void theDefaultPointsAtTheSecondPlane(@TempDir Path dir) throws Exception {
		String asm = compile(dir, "hero", Image.PLANES_POINTER);

		assertTrue(asm.contains("LDU <glb_screen_location_1"), asm);
		assertFalse(asm.contains("LEAU  -8192,U"), asm);
	}

	/**
	 * The offset form must give U back : the caller's cursor over the row is in
	 * it. Returning with U 8192 bytes lower would put the next sprite of the
	 * row in the other plane — visible, but only as garbage in a corner.
	 */
	@Test
	void theOffsetFormWalksThereAndComesBack(@TempDir Path dir) throws Exception {
		String asm = compile(dir, "hero", Image.PLANES_OFFSET);

		assertTrue(asm.contains("LEAU  -8192,U"), asm);
		assertTrue(asm.contains("LEAU  8192,U"), asm);
		assertFalse(asm.contains("glb_screen_location_1"), asm);
		assertTrue(asm.indexOf("LEAU  -8192,U") < asm.indexOf("LEAU  8192,U"),
				"the walk back has to come last\n" + asm);
	}

	/** the distance is a machine constant, so it is declared, not guessed */
	@Test
	void thePlaneDistanceIsTheDeclaredOne(@TempDir Path dir) throws Exception {
		VideoMemory.memoryPlaneDistance = 4096;
		File png = sprite(dir, "hero");
		Image image = new Image("hero", 0, png.getAbsolutePath(), Image.TYPE_DRAW,
				Mirror.NONE, 0, Image.POSITION_CENTER, Image.PLANES_OFFSET);
		image.encode(dir.toString());

		String asm = Files.readString(dir.resolve(image.getFullName() + ".asm"));
		assertTrue(asm.contains("LEAU  -4096,U"), asm);
	}

	/**
	 * bdraw saves and restores a background through its own cells, rle and zx0
	 * stream : none of them addresses the planes the way this option describes,
	 * so asking for it there is a configuration error rather than a silent
	 * no-op.
	 */
	@Test
	void theOffsetFormIsRefusedOnTheOtherEncoders(@TempDir Path dir) throws Exception {
		File png = sprite(dir, "hero");
		assertThrows(Exception.class, () -> new Image("hero", 0, png.getAbsolutePath(),
				Image.TYPE_BDRAW, Mirror.NONE, 0, Image.POSITION_CENTER, Image.PLANES_OFFSET));
	}

	@Test
	void anUnknownConventionIsRefused(@TempDir Path dir) throws Exception {
		File png = sprite(dir, "hero");
		assertThrows(Exception.class, () -> new Image("hero", 0, png.getAbsolutePath(),
				Image.TYPE_DRAW, Mirror.NONE, 0, Image.POSITION_CENTER, "both"));
	}
}
