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
 * bm4s, the draw encoder : a half transparent pair (one pixel opaque, the
 * other not) is laid apart, its byte read, the opaque pixel's two bits
 * cleared, its colour ORed, written back, before the plane's own code. The
 * rest of the picture compiles exactly as it does with those pixels left
 * out : the pattern code never sees them.
 */
public class HalfPairsTest {

	@BeforeEach
	void bm4sGeometry() {
		VideoMemory.memoryLinearBits = 4;
		VideoMemory.memoryPlanarBits = 8;
		VideoMemory.memoryLineBytes = 40;
		VideoMemory.memoryNbPlanes = 2;
		VideoMemory.memoryPlaneDistance = 8192;
		VideoMemory.videoMode = VideoMode.BM4S;
	}

	@AfterEach
	void backToBm16() {
		VideoMemory.videoMode = VideoMode.BM16;
	}

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

	private static String compile(Path dir, int[][] rows, String encoder, int shift, String position) throws Exception {
		Files.createDirectories(dir);
		File png = dir.resolve("pat.png").toFile();
		ImageIO.write(picture(rows), "png", png);
		Image image = new Image("pat", 0, png.getAbsolutePath(), encoder, Mirror.NONE, shift, position);
		image.encode(dir.toString());
		StringBuilder code = new StringBuilder();
		try (java.util.stream.Stream<Path> files = Files.list(dir)) {
			for (Path f : (Iterable<Path>) files.filter(p -> p.toString().endsWith(".asm")).sorted()::iterator) {
				code.append(Files.readString(f));
			}
		}
		return code.toString();
	}

	@Test
	void packAcceptsAHalfPairWhenAskedAndHalvesNamesItsOpaquePixel() throws Exception {
		// pairs : (0,2) right opaque colour 1, (3,0) left opaque colour 2, (4,4) whole
		BufferedImage src = picture(new int[][] {{0, 2, 3, 0, 4, 4}});
		BufferedImage packed = PixelPairs.pack(src, "t.png", true);
		BufferedImage halves = PixelPairs.halves(src);
		int[] p = new int[3];
		int[] h = new int[3];
		for (int x = 0; x < 3; x++) {
			p[x] = packed.getRaster().getSample(x, 0, 0);
			h[x] = halves.getRaster().getSample(x, 0, 0);
		}
		assertArrayEquals(new int[] {0, 0, 16}, p);     // the half pairs transparent, (4,4) colour 15
		assertArrayEquals(new int[] {2 + 4, 3, 0}, h);  // right pixel : index + 4 ; left : index
		assertThrows(Exception.class, () -> PixelPairs.pack(src, "t.png"));   // the default refuses
	}

	@Test
	void eachHalfPairIsLaidWithItsTwoBitsMasked(@TempDir Path dir) throws Exception {
		// one line, top-left anchored (U on byte 0 of the line) :
		//  pairs 0-1 : plane 0, byte 0 (pair 0 its high nibble, pair 1 its low one)
		//  pairs 2-3 : plane 1, byte 0
		// pair 0 = (0, 2) : the right pixel, colour 1 : bits 5-4 : AND $CF, OR $10
		// pair 1 = (3, 3) : whole
		// pair 2 = (4, 0) : the left pixel, colour 3 : bits 7-6 : AND $3F, OR $C0
		// pair 3 = (0, 0) : transparent
		int[][] rows = {{0, 2, 3, 3, 4, 0, 0, 0}};
		String code = compile(dir.resolve("halves"), rows, Image.TYPE_DRAW, 0, Image.POSITION_TOP_LEFT);
		assertTrue(code.contains("\tLDA 0,U\n\tANDA #$CF\n\tORA #$10\n\tSTA 0,U"), code);
		assertTrue(code.contains("\tLDA 0,U\n\tANDA #$3F\n\tORA #$C0\n\tSTA 0,U"), code);
		// the plane-0 write comes before the plane switch, the plane-1 one after it
		int first = code.indexOf("ORA #$10");
		int mid = code.indexOf("glb_screen_location_1");
		int second = code.indexOf("ORA #$C0");
		assertTrue(first < mid && mid < second, code);
	}

	@Test
	void theRestCompilesAsThePictureWithoutThem(@TempDir Path dir) throws Exception {
		int[][] rows = {
			{1, 2, 3, 4, 0, 3, 2, 1, 0, 0, 2, 2, 3, 0, 4, 2},
			{2, 0, 2, 2, 1, 4, 1, 4, 0, 0, 3, 3, 3, 3, 0, 4},
			{4, 1, 4, 1, 3, 2, 3, 2, 1, 1, 0, 0, 2, 4, 2, 4},
		};
		int[][] without = new int[rows.length][];
		for (int y = 0; y < rows.length; y++) {
			without[y] = rows[y].clone();
			for (int x = 0; x < rows[y].length; x += 2) {
				if ((rows[y][x] == 0) != (rows[y][x + 1] == 0)) {
					without[y][x] = 0;
					without[y][x + 1] = 0;
				}
			}
		}
		for (int shift = 0; shift < 2; shift++) {
			String with = compile(dir.resolve("with" + shift), rows, Image.TYPE_DRAW, shift, Image.POSITION_CENTER);
			String base = compile(dir.resolve("base" + shift), without, Image.TYPE_DRAW, shift, Image.POSITION_CENTER);
			StringBuilder stripped = new StringBuilder();
			String[] lines = with.split("\n", -1);
			boolean planeStart = false;
			for (int i = 0; i < lines.length; i++) {
				// the laid half pairs : LDA / ANDA / ORA / STA at one offset, right at a
				// plane's start (after the routine's label, after the plane switch)
				if (planeStart && i + 3 < lines.length && lines[i].matches("\tLDA -?\\d+,U")
						&& lines[i + 1].startsWith("\tANDA #$") && lines[i + 2].startsWith("\tORA #$")
						&& lines[i + 3].equals("\tSTA " + lines[i].substring(5))) {
					i += 3;
					continue;
				}
				planeStart = lines[i].startsWith("adr_") || lines[i].contains("glb_screen_location_1");
				stripped.append(lines[i]);
				if (i < lines.length - 1) {
					stripped.append('\n');
				}
			}
			assertTrue(with.contains("ANDA #$"), "shift " + shift + " : no half pair laid\n" + with);
			assertEquals(base, stripped.toString(), "shift " + shift);
		}
	}

	@Test
	void theOtherEncodersStillRefuseIt(@TempDir Path dir) {
		Exception e = assertThrows(Exception.class,
				() -> compile(dir.resolve("bdraw"), new int[][] {{2, 2, 0, 3}}, Image.TYPE_BDRAW, 0, Image.POSITION_CENTER));
		assertTrue(e.getMessage().contains("half transparent"), e.getMessage());
	}
}
