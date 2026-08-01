package com.widedot.toolbox.graphics.gfxcomp.imageset;

import static org.junit.jupiter.api.Assertions.assertEquals;
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
import com.widedot.toolbox.graphics.gfxcomp.transformer.mirror.Mirror;
import com.widedot.toolbox.graphics.gfxcomp.transformer.shift.Shift;

/**
 * End to end guard on the index: an imageset holding one compiled image must
 * reference that image's symbols and carry its geometry. Before the variant
 * keys were unified the lookups never matched, so the index came out as a row
 * of zeroes with no symbol at all — structurally valid, silently useless.
 */
public class ImageSetIndexTest {

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

	@Test
	void indexReferencesTheCompiledImage(@TempDir Path dir) throws Exception {
		File png = sprite(dir, "hero");
		Image image = new Image("hero", 3, png.getAbsolutePath(),
		                        Image.TYPE_BDRAW, Mirror.NONE, 0, Image.POSITION_CENTER);
		image.encode(dir.toString());

		assertEquals("NB0", image.getVariant());
		assertEquals("hero_NB0", image.getFullName());

		ImageSet set = new ImageSet(0, "assets.sprites");
		set.addImage(image);
		Path index = dir.resolve("index.asm");
		set.generate(index.toString());

		String asm = Files.readString(index);
		assertTrue(asm.contains("idx_hero equ 3"), asm);
		assertTrue(asm.contains("set_hero"), asm);
		assertTrue(asm.contains("adr_hero_NB0"), asm);
		assertTrue(asm.contains("adr_hero_NB0_erase"), asm);

		// the page is a relocation on the file, with the cartridge window bits,
		// and the addresses are words : an fcb would keep their low byte only
		assertTrue(asm.contains("assets.sprites$PAGE EXTERNAL"), asm);
		assertTrue(asm.contains("fcb   assets.sprites$PAGE+$60"), asm);
		assertTrue(asm.contains("fdb   adr_hero_NB0"), asm);

		// the sub set offset of the unmirrored variant, right after the header
		assertTrue(asm.contains("$07"), asm);
	}

	/**
	 * The imageset keeps one x1/y1 per mirror group, shared by every variant in
	 * it, and lets a shifted variant write them. So a shift must not move the
	 * geometry — which holds only because the planing measures it before the
	 * planes are shifted. It is the invariant the pipeline order exists for.
	 */
	@Test
	void aShiftedVariantDeclaresTheGeometryOfTheUnshiftedOne(@TempDir Path dir) throws Exception {
		File png = sprite(dir, "hero");
		Image flat = new Image("hero", 0, png.getAbsolutePath(),
		                       Image.TYPE_BDRAW, Mirror.NONE, 0, Image.POSITION_CENTER);
		Image shifted = new Image("hero", 0, png.getAbsolutePath(),
		                          Image.TYPE_BDRAW, Mirror.NONE, 1, Image.POSITION_CENTER);

		assertEquals("NB0", flat.getVariant());
		assertEquals("NB1", shifted.getVariant());
		assertEquals(flat.x1_offset, shifted.x1_offset, "x1_offset");
		assertEquals(flat.y1_offset, shifted.y1_offset, "y1_offset");
		assertEquals(flat.x_size, shifted.x_size, "x_size");
		assertEquals(flat.y_size, shifted.y_size, "y_size");
		assertEquals(flat.getCenterOffset(), shifted.getCenterOffset(), "center_offset");
	}

	@Test
	void aWiderShiftIsRefused(@TempDir Path dir) throws Exception {
		File png = sprite(dir, "hero");
		assertThrows(Exception.class, () -> new Image("hero", 0, png.getAbsolutePath(),
		                                              Image.TYPE_BDRAW, Mirror.NONE, 2, Image.POSITION_CENTER));
	}

	@Test
	void aMissingImageFileIsAnError(@TempDir Path dir) {
		assertThrows(Exception.class, () -> new Image("ghost", 0, dir.resolve("nope.png").toString(),
		                                              Image.TYPE_BDRAW, Mirror.NONE, 0, Image.POSITION_CENTER));
	}
}
