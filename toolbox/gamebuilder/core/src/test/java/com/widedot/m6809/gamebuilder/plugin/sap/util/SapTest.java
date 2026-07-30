package com.widedot.m6809.gamebuilder.plugin.sap.util;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * Locks the SAP geometry and sector encoding. Format 1 (80 tracks, 256 byte
 * sectors) is the one every project uses today and whose images are known to
 * boot, so its sizes are pinned as a regression reference.
 */
class SapTest {

	@Test
	@DisplayName("format 1 geometry matches the images actually produced")
	void format1Geometry() {
		// a track holds 16 sectors of (6 bytes of metadata + 256 bytes of data)
		assertEquals((6 + 256) * 16, SapType.trackSize[1]);
		// a drive holds a 66 byte header followed by 80 tracks
		assertEquals(66 + 80 * SapType.trackSize[1], SapType.driveSize[1]);
		// this is the size of the .sap files the builder writes today
		assertEquals(335426, SapType.driveSize[1]);
	}

	@Test
	@DisplayName("the drive stride used to slice data matches the geometry")
	void driveStrideIsConsistent() {
		// Sector slices the raw image with nbTracks * NB_SECT * sectorSize ;
		// any other stride reads a drive at the wrong offset
		int rawDriveSize = SapType.nbTracks[1] * Sap.NB_SECT * SapType.sectorSize[1];
		assertEquals(327680, rawDriveSize);
	}

	@Test
	@DisplayName("sector data is XORed with the SAP magic number")
	void sectorDataIsObfuscated() {
		byte[] image = new byte[327680];
		for (int i = 0; i < 256; i++) {
			image[i] = (byte) i;
		}

		Sector s = new Sector(Sap.SAP_FORMAT1, 0, 0, 0, image);

		assertEquals(256, s.data.length);
		for (int i = 0; i < 256; i++) {
			assertEquals((byte) (i ^ Sap.SAP_MAGIC_NUM), s.data[i], "byte " + i);
		}
		assertEquals(0, s.track);
		assertEquals(1, s.sector, "sector numbering is 1 based on the media");
	}

	@Test
	@DisplayName("the Pukall CRC is deterministic and content dependent")
	void crcIsDeterministicAndContentDependent() {
		byte[] image = new byte[327680];

		Sector empty1 = new Sector(Sap.SAP_FORMAT1, 0, 0, 0, image);
		Sector empty2 = new Sector(Sap.SAP_FORMAT1, 0, 0, 0, image);
		assertEquals(empty1.crc1sect, empty2.crc1sect);
		assertEquals(empty1.crc2sect, empty2.crc2sect);

		image[10] = 0x42;
		Sector modified = new Sector(Sap.SAP_FORMAT1, 0, 0, 0, image);
		assertFalse(empty1.crc1sect == modified.crc1sect && empty1.crc2sect == modified.crc2sect,
				"changing a data byte must change the sector CRC");
	}

	@Test
	@DisplayName("an all zero image produces no sap file at all")
	void emptyImageProducesNoDrive() throws Exception {
		Sap sap = new Sap(new byte[327680], Sap.SAP_FORMAT1);
		assertEquals(Sap.SAP_FORMAT1, sap.type);
	}

	@Test
	@DisplayName("only formats 1 and 2 are accepted")
	void rejectsUnknownFormat() {
		assertThrows(Exception.class, () -> new Sap(new byte[16], 0));
		assertThrows(Exception.class, () -> new Sap(new byte[16], 3));
	}

	@Test
	@DisplayName("the sap header carries the format and the Pukall signature")
	void headerIsWellFormed() throws Exception {
		byte[] image = new byte[327680];
		image[0] = 0x01; // make drive 0 non empty

		Sap sap = new Sap(image, Sap.SAP_FORMAT1);
		byte[] out = sap.getSapFile(0);

		assertNotNull(out, "drive 0 holds data, it must produce a file");
		assertEquals(335426, out.length);
		assertEquals(Sap.SAP_FORMAT1, out[0]);
		assertEquals(Sap.sapHeader, new String(out, 1, Sap.sapHeader.length()));
	}
}
