package com.widedot.toolbox.graphics.gfxcomp.imageset;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
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
import com.widedot.toolbox.graphics.gfxcomp.transformer.mirror.Mirror;

/**
 * share="identical" : two variants drawing the same pixels with the same
 * encoder have the same content key, and a variant sharing another's routine
 * is indexed under that routine's name, its own never declared.
 */
public class SharedVariantsTest {

	private static final com.widedot.m6809.gamebuilder.spi.globals.ImageSets.PageByte PAGE_BYTE =
			new com.widedot.m6809.gamebuilder.spi.globals.ImageSets.PageByte(
					"map.RAM_OVER_CART+", "engine/system/to8/map.const.asm");

	/** an 8x8 indexed sprite, colour 0 transparent, the given cells of colour 1 */
	private static File sprite(Path dir, String name, int[][] cells) throws Exception {
		byte[] r = new byte[17], g = new byte[17], b = new byte[17];
		for (int i = 1; i < 17; i++) { r[i] = (byte) (i * 8); g[i] = (byte) (i * 4); b[i] = (byte) (i * 2); }
		IndexColorModel cm = new IndexColorModel(8, 17, r, g, b, 0);
		BufferedImage img = new BufferedImage(8, 8, BufferedImage.TYPE_BYTE_INDEXED, cm);
		for (int[] c : cells) {
			img.getRaster().setSample(c[0], c[1], 0, 1);
		}
		File file = dir.resolve(name + ".png").toFile();
		ImageIO.write(img, "png", file);
		return file;
	}

	private static Image image(String name, File png, String mirror) throws Exception {
		return new Image(name, null, png.getAbsolutePath(), Image.TYPE_DRAW, mirror, 0,
				Image.POSITION_CENTER);
	}

	@Test
	void aSymmetricImageAndItsMirrorShareAKey(@TempDir Path dir) throws Exception {
		File png = sprite(dir, "ball", new int[][] { { 2, 3 }, { 5, 3 }, { 3, 4 }, { 4, 4 } });
		assertEquals(image("ball", png, Mirror.NONE).contentKey(),
				image("ball", png, Mirror.X).contentKey());
	}

	@Test
	void anAsymmetricImageAndItsMirrorDiffer(@TempDir Path dir) throws Exception {
		File png = sprite(dir, "arrow", new int[][] { { 1, 3 }, { 2, 3 }, { 3, 4 } });
		assertNotEquals(image("arrow", png, Mirror.NONE).contentKey(),
				image("arrow", png, Mirror.X).contentKey());
	}

	@Test
	void anImageTheMirrorOfAnotherSharesItsRoutine(@TempDir Path dir) throws Exception {
		File left = sprite(dir, "left", new int[][] { { 1, 3 }, { 2, 3 }, { 3, 4 } });
		File right = sprite(dir, "right", new int[][] { { 6, 3 }, { 5, 3 }, { 4, 4 } });
		Image leftX = image("left", left, Mirror.X);
		Image rightN = image("right", right, Mirror.NONE);
		assertEquals(leftX.contentKey(), rightN.contentKey());

		leftX.encode(dir.toString());
		rightN.canonical = leftX;
		assertEquals("left_XD0", rightN.routineName());

		ImageSet set = new ImageSet(0, null);
		set.addImage(leftX);
		set.addImage(rightN);
		Path index = dir.resolve("index.asm");
		set.generate(index.toString(), "code", PAGE_BYTE);
		String asm = Files.readString(index);

		// the right image is indexed with the left one's mirrored routine,
		// declared once, and its own routine is never referenced
		assertTrue(asm.contains("set_right"), asm);
		assertEquals(2, asm.split("fdb   adr_left_XD0\\b", -1).length - 1, asm);
		assertEquals(1, asm.split("adr_left_XD0 EXTERNAL", -1).length - 1, asm);
		assertTrue(asm.contains("map.RAM_OVER_CART+adr_left_XD0$PAGE"), asm);
		assertFalse(asm.contains("adr_right_ND0"), asm);
	}
}
