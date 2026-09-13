package com.widedot.toolbox.graphics.gfxcomp.encoder;

import static org.junit.jupiter.api.Assertions.assertEquals;
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
 * Compiled 1bpp sprites for the $26 two-plane mode : one bit per pixel, one
 * screen byte per 8 pixels, bit 7 first. The routine writes a single plane —
 * no mid-routine plane switch — so the same code draws on RAMA or on RAMB,
 * selected by the address the caller passes in U.
 */
public class OneBppTest {

	/** an 8 bit indexed image with a 0/1 palette, ink on the given pixels */
	private static File inked(Path dir, String name, int w, int h, boolean[][] ink) throws Exception {
		byte[] rgb = new byte[] { 0, (byte) 255 };
		IndexColorModel cm = new IndexColorModel(8, 2, rgb, rgb, rgb, 0);
		BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_BYTE_INDEXED, cm);
		for (int y = 0; y < h; y++)
			for (int x = 0; x < w; x++)
				img.getRaster().setSample(x, y, 0, ink[y][x] ? 1 : 0);
		File file = dir.resolve(name + ".png").toFile();
		ImageIO.write(img, "png", file);
		return file;
	}

	private static boolean[][] full(int w, int h) {
		boolean[][] ink = new boolean[h][w];
		for (int y = 0; y < h; y++)
			for (int x = 0; x < w; x++)
				ink[y][x] = true;
		return ink;
	}

	private static void videoMemory() {
		VideoMemory.memoryLinearBits = 4;
		VideoMemory.memoryPlanarBits = 8;
		VideoMemory.memoryLineBytes = 40;
		VideoMemory.memoryNbPlanes = 2;
		VideoMemory.memoryPlaneDistance = 8192;
	}

	private static long countLines(String asm, String token) {
		return asm.lines().filter(l -> l.contains(token)).count();
	}

	@Test
	void bdraw1BacksUpDrawsAndRestoresOnePlane(@TempDir Path dir) throws Exception {
		videoMemory();
		File png = inked(dir, "dot", 8, 8, full(8, 8));
		Image image = new Image("dot", 0, png.getAbsolutePath(), Image.TYPE_BDRAW1,
				Mirror.NONE, 0, Image.POSITION_TOP_LEFT);
		image.encode(dir.toString());

		String draw = Files.readString(dir.resolve(image.getFullName() + ".asm"));
		String erase = Files.readString(dir.resolve(image.getFullName() + "_erase.asm"));

		// same contract as bdraw : Y enters with the cell end, the screen base
		// is pushed first and popped last, U leaves with the saved background
		assertTrue(draw.contains("LEAS ,Y"), draw);
		assertTrue(draw.contains("PSHS U"), draw);
		assertFalse(draw.contains("glb_screen_location_1"), draw);
		assertTrue(erase.contains("PULS U"), erase);

		// 8 rows of one $FF byte : 8 stores on each side, paired by construction
		assertEquals(8, countLines(draw, "STA "), draw);
		assertEquals(8, countLines(erase, "STA "), erase);
		assertTrue(draw.contains("ORA #$FF"), draw);

		// the screen base travels deepest : pushed last, popped first, so
		// every erase restore hits the screen through U, never the cells
		assertEquals(1, countLines(draw, "PSHS U"), draw);
		assertEquals(1, countLines(erase, "PULS U"), erase);
		assertTrue(draw.lastIndexOf("PSHS U") > draw.lastIndexOf("PSHS A"), draw);
		assertTrue(erase.indexOf("PULS U") < erase.indexOf("PULS A"), erase);

		// erase data is the screen base plus one byte per row
		assertTrue(erase.contains("dot_NB0_datasize equ $000A"), erase);
		assertEquals(1, image.nb_cell);
	}

	@Test
	void bitsPackLeftFirst(@TempDir Path dir) throws Exception {
		videoMemory();
		boolean[][] ink = new boolean[8][16];
		for (int y = 0; y < 8; y++)
			for (int x = 0; x < 4; x++)
				ink[y][x] = true;
		File png = inked(dir, "half", 16, 8, ink);
		Image image = new Image("half", 0, png.getAbsolutePath(), Image.TYPE_BDRAW1,
				Mirror.NONE, 0, Image.POSITION_TOP_LEFT);
		image.encode(dir.toString());

		String draw = Files.readString(dir.resolve(image.getFullName() + ".asm"));
		assertTrue(draw.contains("ORA #$F0"), draw);
		// the transparent second byte of every row is skipped, not backed up
		assertTrue(draw.contains("STA 0,U"), draw);
		assertFalse(draw.contains("STA 1,U"), draw);
	}

	@Test
	void draw1SkipsHolesAndHasNoErase(@TempDir Path dir) throws Exception {
		videoMemory();
		boolean[][] ink = new boolean[8][16];
		for (int y = 0; y < 8; y++)
			for (int x = 0; x < 4; x++)
				ink[y][x] = true;
		File png = inked(dir, "sparse", 16, 8, ink);
		Image image = new Image("sparse", 0, png.getAbsolutePath(), Image.TYPE_DRAW1,
				Mirror.NONE, 0, Image.POSITION_TOP_LEFT);
		image.encode(dir.toString());

		String draw = Files.readString(dir.resolve(image.getFullName() + ".asm"));
		assertEquals(8, countLines(draw, "STA "), draw);
		assertFalse(Files.exists(dir.resolve(image.getFullName() + "_erase.asm")));
		assertFalse(draw.contains("PSHS"), draw);
	}

	@Test
	void clear1DrawsWithoutBackupAndClearsOnErase(@TempDir Path dir) throws Exception {
		videoMemory();
		boolean[][] ink = new boolean[8][16];
		for (int y = 0; y < 8; y++)
			for (int x = 0; x < 4; x++)
				ink[y][x] = true;
		File png = inked(dir, "clearme", 16, 8, ink);
		Image image = new Image("clearme", 0, png.getAbsolutePath(), Image.TYPE_CLEAR1,
				Mirror.NONE, 0, Image.POSITION_TOP_LEFT);
		image.encode(dir.toString());

		String draw = Files.readString(dir.resolve(image.getFullName() + ".asm"));
		String erase = Files.readString(dir.resolve(image.getFullName() + "_erase.asm"));

		// 8 rows of one $F0 byte : 8 stores, the transparent second byte of
		// every row skipped, no backup pushed anywhere
		assertEquals(8, countLines(draw, "STA "), draw);
		assertTrue(draw.contains("ORA #$F0"), draw);
		assertFalse(draw.contains("PSHS"), draw);
		assertFalse(draw.contains("STA 1,U"), draw);

		// erase zeroes exactly the drawn bytes (D = 0, stored) : no pull, and
		// no data travels, so no cell is ever allocated for this variant
		assertTrue(erase.contains("LDD #$0000"), erase);
		assertEquals(8, countLines(erase, "STA 0,U"), erase);
		assertFalse(erase.contains("PULS"), erase);
		assertFalse(erase.contains("LDA "), erase);
		assertTrue(erase.contains("clearme_NB0_datasize equ $0000"), erase);
		assertEquals(0, image.nb_cell);
	}

	@Test
	void emptyImageIsAConsistentNoOp(@TempDir Path dir) throws Exception {
		videoMemory();
		File png = inked(dir, "blank", 8, 8, new boolean[8][8]);
		Image image = new Image("blank", 0, png.getAbsolutePath(), Image.TYPE_BDRAW1,
				Mirror.NONE, 0, Image.POSITION_TOP_LEFT);
		image.encode(dir.toString());

		String draw = Files.readString(dir.resolve(image.getFullName() + ".asm"));
		String erase = Files.readString(dir.resolve(image.getFullName() + "_erase.asm"));
		assertEquals(0, countLines(draw, "STA "), draw);
		assertEquals(0, countLines(erase, "STA "), erase);
		assertTrue(erase.contains("blank_NB0_datasize equ $0002"), erase);
	}

	@Test
	void onlyTransparentAndInkAreAccepted(@TempDir Path dir) throws Exception {
		videoMemory();
		byte[] rgb = new byte[] { 0, (byte) 255, (byte) 128 };
		IndexColorModel cm = new IndexColorModel(8, 3, rgb, rgb, rgb, 0);
		BufferedImage img = new BufferedImage(8, 8, BufferedImage.TYPE_BYTE_INDEXED, cm);
		img.getRaster().setSample(0, 0, 0, 2);
		File file = dir.resolve("shade.png").toFile();
		ImageIO.write(img, "png", file);

		assertThrows(Exception.class, () -> new Image("shade", 0, file.getAbsolutePath(),
				Image.TYPE_BDRAW1, Mirror.NONE, 0, Image.POSITION_TOP_LEFT));
	}

	@Test
	void onlyShiftZeroIsSupported(@TempDir Path dir) throws Exception {
		videoMemory();
		File png = inked(dir, "shifted", 8, 8, full(8, 8));
		assertThrows(Exception.class, () -> new Image("shifted", 0, png.getAbsolutePath(),
				Image.TYPE_BDRAW1, Mirror.NONE, 1, Image.POSITION_TOP_LEFT));
	}

	@Test
	void widerThanAPlaneLineIsRefused(@TempDir Path dir) throws Exception {
		videoMemory();
		File png = inked(dir, "wide", 328, 8, full(328, 8));
		assertThrows(Exception.class, () -> new Image("wide", 0, png.getAbsolutePath(),
				Image.TYPE_BDRAW1, Mirror.NONE, 0, Image.POSITION_TOP_LEFT));
	}

	@Test
	void theOffsetPlaneConventionIsRefused(@TempDir Path dir) throws Exception {
		videoMemory();
		File png = inked(dir, "off", 8, 8, full(8, 8));
		assertThrows(Exception.class, () -> new Image("off", 0, png.getAbsolutePath(),
				Image.TYPE_BDRAW1, Mirror.NONE, 0, Image.POSITION_TOP_LEFT, Image.PLANES_OFFSET));
	}

	@Test
	void preShiftedVariantsKeepTheirBitAndShareTheAnchor(@TempDir Path dir) throws Exception {
		videoMemory();
		// one 24x8 canvas, a 4 px wide ink bar at column 2+s : eight variants
		// of one sprite whose ink only moved. The packed box starts on the byte
		// boundary before the ink, so the bar keeps its bit position, and the
		// code is anchored on the canvas centre byte (byte 1 of 3), so
		// x1_offset(s) = x1_offset(0) + s and the variants draw 1 px apart.
		String[] draws = new String[8];
		int[] x1 = new int[8];
		for (int s = 0; s < 8; s++) {
			boolean[][] ink = new boolean[8][24];
			for (int y = 0; y < 8; y++)
				for (int x = 2 + s; x < 6 + s; x++)
					ink[y][x] = true;
			File png = inked(dir, "bar" + s, 24, 8, ink);
			Image image = new Image("bar" + s, 0, png.getAbsolutePath(), Image.TYPE_DRAW1,
					Mirror.NONE, 0, Image.POSITION_CENTER);
			image.encode(dir.toString());
			draws[s] = Files.readString(dir.resolve(image.getFullName() + ".asm"));
			x1[s] = image.getSubImageX1Offset();
		}
		// centre pixel 11 -> reference byte 1 : x1 is the ink column minus 8
		assertEquals(-6, x1[0]);
		for (int s = 1; s < 8; s++)
			assertEquals(x1[0] + s, x1[s], "variant " + s);
		// bits move with the ink : %00111100, %00011110, ... then the bar
		// straddles two bytes, then lands at bit 7 of the second byte
		assertTrue(draws[0].contains("ORA #$3C"), draws[0]);
		assertTrue(draws[1].contains("ORA #$1E"), draws[1]);
		assertTrue(draws[5].contains("ORA #$01") && draws[5].contains("ORB #$E0"), draws[5]);
		assertTrue(draws[6].contains("ORA #$F0"), draws[6]);
		// U walks : one LEAU to the packed box (row 0 is 3 rows above the
		// reference row, variant 0 one byte left of the reference byte,
		// variant 6 with ink at 8..11 on the reference byte itself), then
		// 5-bit offsets only
		assertTrue(draws[0].contains("LEAU -121,U"), draws[0]);
		assertTrue(draws[6].contains("LEAU -120,U"), draws[6]);
		assertTrue(draws[0].contains("STA 0,U"), draws[0]);
		assertFalse(draws[0].contains(",U\n\tANDA"), draws[0]);
		assertEquals(8, countLines(draws[0], "LEAU "), draws[0]);
	}
}
