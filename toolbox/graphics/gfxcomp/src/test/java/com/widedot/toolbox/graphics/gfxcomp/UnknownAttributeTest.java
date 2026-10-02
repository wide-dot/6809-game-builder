package com.widedot.toolbox.graphics.gfxcomp;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.awt.image.BufferedImage;
import java.awt.image.IndexColorModel;
import java.io.File;
import java.nio.file.Path;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import com.widedot.toolbox.graphics.gfxcomp.transformer.mirror.Mirror;

/**
 * A value outside an attribute's table is a named build error. It used to be a
 * NullPointerException raised by unboxing, far from the cause : that is what a
 * build met when its config named an encoder (clear1) that the gfxcomp jar in
 * repo/ predated.
 */
public class UnknownAttributeTest {

	private static String sprite(Path dir) throws Exception {
		byte[] r = new byte[2], g = new byte[2], b = new byte[2];
		IndexColorModel cm = new IndexColorModel(8, 2, r, g, b, 0);
		BufferedImage img = new BufferedImage(8, 8, BufferedImage.TYPE_BYTE_INDEXED, cm);
		File file = dir.resolve("hero.png").toFile();
		ImageIO.write(img, "png", file);
		return file.getAbsolutePath();
	}

	private static String refusal(Path dir, String encoder, String mirror, String position) throws Exception {
		String png = sprite(dir);
		Exception e = assertThrows(Exception.class,
				() -> new Image("hero", 0, png, encoder, mirror, 0, position));
		assertEquals(Exception.class, e.getClass(), "a named build error, not " + e.getClass().getSimpleName());
		return e.getMessage();
	}

	@Test
	void anUnknownEncoderIsNamedWithTheKnownOnes(@TempDir Path dir) throws Exception {
		String m = refusal(dir, "clear2", Mirror.NONE, Image.POSITION_CENTER);
		assertTrue(m.contains("hero") && m.contains("encoder 'clear2'"), m);
		assertTrue(m.contains(Image.TYPE_CLEAR1) && m.contains(Image.TYPE_BDRAW), m);
		assertTrue(m.contains("repo/"), m);
	}

	@Test
	void anUnknownMirrorIsNamed(@TempDir Path dir) throws Exception {
		String m = refusal(dir, Image.TYPE_DRAW, "diagonal", Image.POSITION_CENTER);
		assertTrue(m.contains("mirror 'diagonal'") && m.contains(Mirror.XY), m);
	}

	@Test
	void anUnknownPositionIsNamed(@TempDir Path dir) throws Exception {
		String m = refusal(dir, Image.TYPE_DRAW, Mirror.NONE, "bottom");
		assertTrue(m.contains("position 'bottom'") && m.contains(Image.POSITION_CENTER), m);
	}
}
