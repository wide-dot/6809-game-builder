package com.widedot.m6809.gamebuilder.plugin.sd;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * The .sd file : SDDRIVE's units, 0-1 the first drive's faces, 2-3 the
 * second's ; a sector 256 bytes of data then 256 of 0xFF.
 */
class SdPluginTest {

	@Test
	@DisplayName("a sector takes 512 bytes, its second half 0xFF")
	void sectorPadding() {
		byte[] data = new byte[512];
		data[0] = 1;
		data[256] = 2;
		byte[] sd = SdPlugin.sectors(data);
		assertEquals(1024, sd.length);
		assertEquals(1, sd[0]);
		assertEquals((byte) 0xFF, sd[256]);
		assertEquals(2, sd[512]);
		assertEquals((byte) 0xFF, sd[1023]);
	}

	@Test
	@DisplayName("the second drive's disk lands at unit 2, after the first drive's two units")
	void secondDriveAtUnitTwo() {
		byte[] first = new byte[2 * SdPlugin.UNIT_BYTES];
		byte[] second = new byte[2 * SdPlugin.UNIT_BYTES];
		second[0] = 7;
		byte[] out = SdPlugin.place(first, second, 1);
		assertEquals(4 * SdPlugin.UNIT_BYTES, out.length);
		assertEquals(7, out[2 * SdPlugin.UNIT_BYTES]);
	}

	@Test
	@DisplayName("a one-face first disk : its missing unit is padded, unformatted")
	void oneFaceFirstDiskPadded() {
		byte[] first = new byte[SdPlugin.UNIT_BYTES];
		byte[] second = new byte[SdPlugin.UNIT_BYTES];
		second[0] = 9;
		byte[] out = SdPlugin.place(first, second, 1);
		assertEquals((byte) 0xFF, out[SdPlugin.UNIT_BYTES]);
		assertEquals(9, out[2 * SdPlugin.UNIT_BYTES]);
	}

	@Test
	@DisplayName("the first drive written after the second keeps units 2-3")
	void firstDriveAfterSecond() {
		byte[] second = new byte[2 * SdPlugin.UNIT_BYTES];
		second[0] = 5;
		byte[] withSecond = SdPlugin.place(new byte[0], second, 1);
		assertEquals((byte) 0xFF, withSecond[0], "units 0-1 not written yet : unformatted");
		byte[] first = new byte[2 * SdPlugin.UNIT_BYTES];
		first[0] = 3;
		byte[] out = SdPlugin.place(withSecond, first, 0);
		assertEquals(4 * SdPlugin.UNIT_BYTES, out.length);
		assertEquals(3, out[0]);
		assertEquals(5, out[2 * SdPlugin.UNIT_BYTES]);
	}
}
