package com.widedot.toolbox.graphics.png;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

import com.widedot.m6809.util.zx0.Decompressor;

/**
 * codec="zx0" keeps a plane compressed in RAM : the stream must be the one the
 * engine's decompressor reads (the loader's classic format, forward, no
 * in-place byte), and decompress to the plane's bytes exactly.
 */
public class CodecTest {

	/** a plane like a title card : runs of one byte, a repeated pattern, noise */
	private static byte[] plane() {
		byte[] b = new byte[8000];
		for (int i = 0; i < b.length; i++) {
			int line = i / 40;
			if (line < 60) {
				b[i] = 0;
			} else if (line < 140) {
				b[i] = (byte) ((i % 40) < 20 ? 0x55 : 0xAA);
			} else {
				b[i] = (byte) (i * 131 ^ line * 7);
			}
		}
		return b;
	}

	@Test
	void zx0DecompressesToThePlane() throws Exception {
		byte[] raw = plane();
		byte[] packed = Png2BinPlugin.encode(raw, "zx0");
		assertTrue(packed.length < raw.length / 2, "packed " + packed.length);
		// classic format : no inversion, forward (the loader's zx0_6809_mega.asm)
		assertArrayEquals(raw, new Decompressor().decompress(packed, false, false));
	}

	@Test
	void noneIsThePlaneAsItIs() throws Exception {
		byte[] raw = plane();
		assertSame(raw, Png2BinPlugin.encode(raw, "none"));
		assertSame(raw, Png2BinPlugin.encode(raw, "NONE"));
	}

	@Test
	void anUnknownCodecIsRefused() {
		Exception e = assertThrows(Exception.class, () -> Png2BinPlugin.codec("lz4"));
		assertTrue(e.getMessage().contains("codec 'lz4'"), e.getMessage());
	}
}
