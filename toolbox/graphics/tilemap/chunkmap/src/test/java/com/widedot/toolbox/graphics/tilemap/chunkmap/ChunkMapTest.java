package com.widedot.toolbox.graphics.tilemap.chunkmap;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.awt.image.BufferedImage;
import java.awt.image.IndexColorModel;
import java.awt.image.WritableRaster;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * A synthetic zone : cells of 2x2 pixels, three source chunks (0 empty, 1
 * and 2 the same), three blocks and an animated one.
 */
class ChunkMapTest {

	private static final int TW = 2, TH = 2;

	/** chunk 1 and 2 : the cells' mapping words */
	private static final int[] WORDS = {
			0xC401, // block 1, x flip, solidity C
			0xC401, // the same : the same tile
			0x0002, // block 2 : the same picture, another collision
			0xC401, // block 1 again, its picture differing on the odd line only
			0x0000, // empty
			0x0005, // animated block 5
	};

	private static BufferedImage sheet() {
		byte[] r = { 0, (byte) 255, 0, 0 }, g = { 0, 0, (byte) 255, 0 }, b = { 0, 0, 0, (byte) 255 };
		IndexColorModel cm = new IndexColorModel(8, 4, r, g, b, 0);
		BufferedImage im = new BufferedImage(8 * TW, 3 * 8 * TH, BufferedImage.TYPE_BYTE_INDEXED, cm);
		WritableRaster w = im.getRaster();
		for (int c = 1; c <= 2; c++) {
			for (int cell = 0; cell < 4; cell++) {
				int x = cell * TW, y = c * 8 * TH;
				w.setSample(x, y, 0, 1);
				w.setSample(x + 1, y, 0, 2);
				w.setSample(x, y + 1, 0, cell == 3 ? 1 : 3);
				w.setSample(x + 1, y + 1, 0, 3);
			}
		}
		return im;
	}

	private static byte[] mappings() {
		byte[] m = new byte[3 * 128];
		for (int c = 1; c <= 2; c++) {
			for (int i = 0; i < WORDS.length; i++) {
				m[c * 128 + i * 2] = (byte) (WORDS[i] >> 8);
				m[c * 128 + i * 2 + 1] = (byte) WORDS[i];
			}
		}
		return m;
	}

	private static byte[] blocks() {
		byte[] b = new byte[3 * 8];
		b[8] = (byte) 0x80;                     // block 1 : high priority
		return b;
	}

	private static List<byte[]> layouts() {
		byte[] l = new byte[2 * 256];
		l[0] = 1;
		l[1] = 2;
		l[256 + 2] = 1;
		l[128] = 2;                             // the background : not read
		return new ArrayList<byte[]>(List.of(l));
	}

	private static ChunkMap.Result convert(boolean halfline, boolean opaque) throws Exception {
		return ChunkMap.convert(sheet(), mappings(), blocks(), new byte[] { 0, 0x10, 0x20 },
				new byte[] { 0, 0x11, 0x21 }, layouts(), halfline, opaque, ChunkMap.parseAnimated("5/high"));
	}

	@Test
	void mergesTilesOnPictureAndCollision() throws Exception {
		ChunkMap.Result r = convert(true, true);
		// 0 empty, 1 block 1's picture, 2 the same picture with block 2's collision ;
		// the odd line differing does not count in half-line
		assertEquals(3, r.tileCount);
		assertArrayEquals(new byte[] { 0, 0x10, 0x20 }, r.primary);
		assertArrayEquals(new byte[] { 0, 0x11, 0x21 }, r.secondary);
		assertArrayEquals(new byte[] { 0, 1, 0 }, r.flip);
	}

	@Test
	void writesTheEntries() throws Exception {
		ChunkMap.Result r = convert(true, true);
		// chunks 1 and 2 are one zone chunk
		assertEquals(2, r.chunks.size());
		int[] e = r.chunks.get(1);
		assertEquals(0x8000 | 0xC << 11 | 0x400 | 1, e[0]);
		assertEquals(e[0], e[1]);
		assertEquals(0x400 | 2, e[2]);
		assertEquals(e[0], e[3]);
		assertEquals(0, e[4]);
		// the animated block : past the tileset, high as declared, not opaque
		assertEquals(0x8000 | 3, e[5]);
		assertTrue(Arrays.stream(r.chunks.get(0)).allMatch(v -> v == 0));
	}

	@Test
	void keepsTheIndexOnElevenBitsWithoutOpaque() throws Exception {
		assertEquals(0x8000 | 0xC << 11 | 1, convert(true, false).chunks.get(1)[0]);
	}

	@Test
	void comparesEveryLineInFullLine() throws Exception {
		// the odd line now tells cell 3 apart : a fourth tile
		assertEquals(4, convert(false, true).tileCount);
	}

	@Test
	void writesThePlaneOnZoneChunks() throws Exception {
		byte[] l = convert(true, true).layouts.get(0);
		assertEquals(2 * 128, l.length);
		assertEquals(1, l[0]);
		assertEquals(1, l[1]);
		assertEquals(1, l[128 + 2]);
		assertEquals(0, l[2]);
	}

	@Test
	void emptiesTheOddLines() throws Exception {
		BufferedImage t = convert(true, true).tiles;
		assertEquals(TW, t.getWidth());
		assertEquals(3 * TH, t.getHeight());
		assertEquals(1, t.getRaster().getSample(0, TH, 0));
		assertEquals(0, t.getRaster().getSample(0, TH + 1, 0));
	}

	@Test
	void refusesAnUndeclaredBlockPastTheMappings() {
		Exception e = assertThrows(Exception.class, () -> ChunkMap.convert(sheet(), mappings(), blocks(),
				new byte[3], new byte[3], layouts(), true, true, ChunkMap.parseAnimated(null)));
		assertTrue(e.getMessage().contains("block 5"), e.getMessage());
	}

	@Test
	void refusesAnUnknownAnimatedFlag() {
		assertThrows(Exception.class, () -> ChunkMap.parseAnimated("761/hi"));
	}

	@Test
	void splitsTheBanks(@TempDir Path dir) throws Exception {
		List<int[]> chunks = new ArrayList<int[]>();
		for (int c = 0; c < 130; c++) {
			int[] e = new int[64];
			e[0] = c;
			chunks.add(e);
		}
		ChunkMap.Result r = new ChunkMap.Result(convert(true, true).tiles, 3, chunks,
				List.of(new byte[128]), new byte[3], new byte[3], new byte[3]);
		ChunkMap.write(r, dir);
		assertEquals(128 * 128, Files.size(dir.resolve("chunk_0.bin")));
		assertEquals(2 * 128, Files.size(dir.resolve("chunk_1.bin")));
		byte[] b1 = Files.readAllBytes(dir.resolve("chunk_1.bin"));
		assertEquals(129, b1[128 + 1] & 0xFF);
		assertArrayEquals(new byte[] { 0, 0, 0, 1, 0, 2 }, Files.readAllBytes(dir.resolve("tiles.bin")));
	}
}
