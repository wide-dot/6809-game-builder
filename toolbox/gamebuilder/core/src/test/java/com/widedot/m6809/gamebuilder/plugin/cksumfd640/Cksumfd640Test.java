package com.widedot.m6809.gamebuilder.plugin.cksumfd640;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * The fd640 boot sector checksum is applied in place on the 128 first bytes of
 * the boot sector : bytes 0..119 are two's complement encoded and accumulated
 * into byte 127, then the BASIC2 signature at 120..125 is accumulated too.
 */
class Cksumfd640Test {

	@Test
	@DisplayName("an all zero sector yields the seed checksum and stays zero")
	void allZeroSector() {
		byte[] data = new byte[128];

		Cksumfd640Plugin.checksum(data);

		// 0x55 seed, adding zeros keeps it, and (256 - 0) is 0 as a byte
		assertEquals((byte) 0x55, data[127]);
		for (int i = 0; i < 120; i++) {
			assertEquals(0, data[i], "byte " + i);
		}
	}

	@Test
	@DisplayName("payload bytes are two's complement encoded")
	void payloadIsEncoded() {
		byte[] data = new byte[128];
		data[0] = 0x01;
		data[1] = 0x02;
		data[119] = 0x7f;

		Cksumfd640Plugin.checksum(data);

		assertEquals((byte) 0xff, data[0], "1 encodes to -1");
		assertEquals((byte) 0xfe, data[1], "2 encodes to -2");
		assertEquals((byte) 0x81, data[119], "127 encodes to -127");
	}

	@Test
	@DisplayName("the checksum accumulates the payload and the signature area")
	void checksumAccumulates() {
		byte[] data = new byte[128];
		data[0] = 0x10;
		data[5] = 0x20;
		data[120] = 0x03; // signature area, accumulated as its two's complement

		Cksumfd640Plugin.checksum(data);

		int expected = 0x55 + 0x10 + 0x20 + (256 - 0x03);
		assertEquals((byte) expected, data[127]);
	}

	@Test
	@DisplayName("bytes 120 to 125 are left untouched")
	void signatureAreaIsPreserved() {
		byte[] data = new byte[128];
		for (int i = 120; i <= 125; i++) {
			data[i] = (byte) (0xA0 + i - 120);
		}

		Cksumfd640Plugin.checksum(data);

		for (int i = 120; i <= 125; i++) {
			assertEquals((byte) (0xA0 + i - 120), data[i], "byte " + i);
		}
	}

	@Test
	@DisplayName("running the checksum twice does not yield the same sector")
	void checksumIsNotIdempotent() {
		byte[] once = new byte[128];
		once[0] = 0x42;
		Cksumfd640Plugin.checksum(once);

		byte[] twice = once.clone();
		Cksumfd640Plugin.checksum(twice);

		assertNotEquals(once[127], twice[127],
				"the routine mutates its input, applying it twice must be visible");
	}
}
