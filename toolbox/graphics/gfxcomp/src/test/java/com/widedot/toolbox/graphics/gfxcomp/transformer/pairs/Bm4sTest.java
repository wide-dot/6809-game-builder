package com.widedot.toolbox.graphics.gfxcomp.transformer.pairs;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.awt.image.BufferedImage;
import java.awt.image.IndexColorModel;
import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import com.widedot.toolbox.graphics.gfxcomp.Image;
import com.widedot.toolbox.graphics.gfxcomp.setting.VideoMemory;
import com.widedot.toolbox.graphics.gfxcomp.setting.VideoMode;
import com.widedot.toolbox.graphics.gfxcomp.transformer.mirror.Mirror;

/**
 * videomode="bm4s" : a 320 pixel picture in 4 colours is packed by pixel pairs
 * into the 160 pixel BM16 picture that draws it in the $41 mode, and from
 * there the encoders run unchanged. The proof that nothing downstream sees a
 * difference : a bm4s source compiles to exactly the code of its hand-packed
 * BM16 twin.
 */
public class Bm4sTest {

	@BeforeEach
	void bm16Geometry() {
		VideoMemory.memoryLinearBits = 4;
		VideoMemory.memoryPlanarBits = 8;
		VideoMemory.memoryLineBytes = 40;
		VideoMemory.memoryNbPlanes = 2;
		VideoMemory.memoryPlaneDistance = 8192;
	}

	@AfterEach
	void backToBm16() {
		VideoMemory.videoMode = VideoMode.BM16;
	}

	/** an 8 bit indexed picture of the given indexes, row by row */
	private static BufferedImage picture(int[][] rows) {
		byte[] r = new byte[17];
		byte[] g = new byte[17];
		byte[] b = new byte[17];
		for (int i = 1; i < 17; i++) {
			r[i] = (byte) (i * 15);
			g[i] = (byte) (i * 7);
			b[i] = (byte) (i * 3);
		}
		IndexColorModel cm = new IndexColorModel(8, 17, r, g, b, 0);
		BufferedImage img = new BufferedImage(rows[0].length, rows.length, BufferedImage.TYPE_BYTE_INDEXED, cm);
		for (int y = 0; y < rows.length; y++) {
			for (int x = 0; x < rows[y].length; x++) {
				img.getRaster().setSample(x, y, 0, rows[y][x]);
			}
		}
		return img;
	}

	private static int[] row(BufferedImage img, int y) {
		int[] out = new int[img.getWidth()];
		for (int x = 0; x < out.length; x++) {
			out[x] = img.getRaster().getSample(x, y, 0);
		}
		return out;
	}

	@Test
	void aPairIsTheBm16ColourLeftShiftedTwiceOrRight() throws Exception {
		// colours 0..3 are indexes 1..4 ; the pair (l, r) is BM16 colour l<<2|r, index +1
		BufferedImage packed = PixelPairs.pack(picture(new int[][] {{1, 1, 1, 4, 4, 1, 4, 4, 2, 3}}), "t.png");
		assertEquals(5, packed.getWidth());
		assertArrayEquals(new int[] {1, 4, 13, 16, 7}, row(packed, 0));
	}

	@Test
	void aTransparentPairStaysTransparent() throws Exception {
		BufferedImage packed = PixelPairs.pack(picture(new int[][] {{0, 0, 2, 2}}), "t.png");
		assertArrayEquals(new int[] {0, 6}, row(packed, 0));
	}

	@Test
	void aHalfTransparentPairIsRefused() {
		Exception e = assertThrows(Exception.class,
				() -> PixelPairs.pack(picture(new int[][] {{2, 2, 0, 3}}), "t.png"));
		assertTrue(e.getMessage().contains("(2,0)-(3,0)") && e.getMessage().contains("half transparent"),
				e.getMessage());
	}

	@Test
	void aFifthColourIsRefused() {
		Exception e = assertThrows(Exception.class,
				() -> PixelPairs.pack(picture(new int[][] {{1, 5}}), "t.png"));
		assertTrue(e.getMessage().contains("pixel (1,0) has index 5"), e.getMessage());
	}

	@Test
	void anOddWidthIsRefused() {
		Exception e = assertThrows(Exception.class,
				() -> PixelPairs.pack(picture(new int[][] {{1, 1, 1}}), "t.png"));
		assertTrue(e.getMessage().contains("must be even"), e.getMessage());
	}

	@Test
	void aModeNameIsReadInAnyCase() throws Exception {
		assertEquals(VideoMode.BM4S, VideoMode.check("BM4S"));
	}

	@Test
	void anUnknownModeIsRefusedWithTheKnownOnes() {
		Exception e = assertThrows(Exception.class, () -> VideoMode.check("t1s"));
		assertTrue(e.getMessage().contains("[bm16, bm4s]"), e.getMessage());
	}

	@Test
	void theOneBitEncodersHaveNoBm4sForm(@TempDir Path dir) throws Exception {
		File png = dir.resolve("dot.png").toFile();
		ImageIO.write(picture(new int[][] {{1, 1, 1, 1, 1, 1, 1, 1}}), "png", png);
		VideoMemory.videoMode = VideoMode.BM4S;
		Exception e = assertThrows(Exception.class, () -> new Image("dot", 0, png.getAbsolutePath(),
				Image.TYPE_BDRAW1, Mirror.NONE, 0, Image.POSITION_CENTER));
		assertTrue(e.getMessage().contains("no bm4s form"), e.getMessage());
	}

	/** the code a picture compiles to with an encoder, in a directory of its own */
	private static String compile(Path dir, BufferedImage img, String encoder, int shift) throws Exception {
		Files.createDirectories(dir);
		File png = dir.resolve("pat.png").toFile();
		ImageIO.write(img, "png", png);
		Image image = new Image("pat", 0, png.getAbsolutePath(), encoder, Mirror.NONE, shift, Image.POSITION_CENTER);
		image.encode(dir.toString());
		StringBuilder code = new StringBuilder();
		try (java.util.stream.Stream<Path> files = Files.list(dir)) {
			for (Path f : (Iterable<Path>) files.filter(p -> p.toString().endsWith(".asm")).sorted()::iterator) {
				code.append(f.getFileName()).append('\n').append(Files.readString(f));
			}
		}
		return code.toString();
	}

	@Test
	void aBm4sSourceCompilesToItsBm16TwinsCode(@TempDir Path dir) throws Exception {
		// 16x4 at 320 : single pixel detail, all four colours, a transparent pair
		int[][] src = {
			{1, 2, 3, 4, 4, 3, 2, 1, 0, 0, 2, 2, 3, 1, 4, 2},
			{2, 2, 2, 2, 1, 4, 1, 4, 0, 0, 3, 3, 3, 3, 4, 4},
			{4, 1, 4, 1, 3, 2, 3, 2, 1, 1, 0, 0, 2, 4, 2, 4},
			{3, 3, 4, 4, 1, 1, 2, 2, 4, 3, 0, 0, 1, 2, 3, 4},
		};
		int[][] twin = new int[src.length][src[0].length / 2];
		for (int y = 0; y < src.length; y++) {
			for (int x = 0; x < twin[y].length; x++) {
				int l = src[y][2 * x];
				int r = src[y][2 * x + 1];
				twin[y][x] = l == 0 ? 0 : ((l - 1) << 2 | (r - 1)) + 1;
			}
		}
		for (String encoder : new String[] {Image.TYPE_DRAW, Image.TYPE_BDRAW}) {
			for (int shift = 0; shift < 2; shift++) {
				VideoMemory.videoMode = VideoMode.BM4S;
				String bm4s = compile(dir.resolve(encoder + shift + "-bm4s"), picture(src), encoder, shift);
				VideoMemory.videoMode = VideoMode.BM16;
				String bm16 = compile(dir.resolve(encoder + shift + "-bm16"), picture(twin), encoder, shift);
				assertTrue(bm4s.contains("pat_") && bm4s.length() > 200, "no code compiled\n" + bm4s);
				assertEquals(bm16, bm4s, encoder + " shift " + shift);
			}
		}
		// the control : the pairs read right to left give another picture,
		// so the comparison above can tell a wrong packing from the right one
		int[][] swapped = new int[src.length][src[0].length / 2];
		for (int y = 0; y < src.length; y++) {
			for (int x = 0; x < swapped[y].length; x++) {
				int l = src[y][2 * x];
				int r = src[y][2 * x + 1];
				swapped[y][x] = l == 0 ? 0 : ((r - 1) << 2 | (l - 1)) + 1;
			}
		}
		VideoMemory.videoMode = VideoMode.BM4S;
		String bm4s = compile(dir.resolve("control-bm4s"), picture(src), Image.TYPE_DRAW, 0);
		VideoMemory.videoMode = VideoMode.BM16;
		String wrong = compile(dir.resolve("control-bm16"), picture(swapped), Image.TYPE_DRAW, 0);
		assertTrue(!bm4s.equals(wrong), "swapped pairs must not compile to the same code");
	}
}
