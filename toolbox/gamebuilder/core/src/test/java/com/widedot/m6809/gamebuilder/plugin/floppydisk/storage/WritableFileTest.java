package com.widedot.m6809.gamebuilder.plugin.floppydisk.storage;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Storages;

/**
 * {@code <file writable="true">} : the builder side of loader.file.save. A writable file is
 * stored on whole sectors of its own, so the loader can write it back without touching a
 * neighbour and read it straight into RAM.
 */
class WritableFileTest {

	@TempDir
	Path dir;

	private static final String FD640 =
		"<configuration>\n" +
		"  <floppydisk model=\"fd640\">\n" +
		"    <segment faces=\"2\" tracks=\"80\" sectors=\"16\" sectorSize=\"256\"/>\n" +
		"    <interleave softskip=\"2\" softskew=\"4\" hardskip=\"7\"/>\n" +
		"    <fat sectorperblock=\"8\" nblocks=\"160\" sectorsize=\"255\" fatstart=\"129\" dirstart=\"512\" ndirentries=\"112\"/>\n" +
		"    <section name=\"DATA\" track=\"1\" face=\"0\" sector=\"1\"/>\n" +
		"  </floppydisk>\n" +
		"</configuration>\n";

	private FdUtil media() throws Exception {
		Path f = dir.resolve("storage.xml");
		Files.write(f, FD640.getBytes(StandardCharsets.UTF_8));
		return new FdUtil(new Storages(f.toString()).get("fd640"));
	}

	private static byte[] bytes(int n, int value) {
		byte[] b = new byte[n];
		java.util.Arrays.fill(b, (byte) value);
		return b;
	}

	@Test
	@DisplayName("a writable file skips the sector its neighbour began and owns whole sectors")
	void ownSectors() throws Exception {
		FdUtil media = media();
		byte[] before = media.cwrite("DATA", bytes(100, 0xA5), "before");
		byte[] save = media.cwriteWhole("DATA", bytes(512, 0x11), "save");
		byte[] after = media.cwrite("DATA", bytes(100, 0x5A), "after");

		// before : track 1 face 0, logical sector 0, 100 bytes from offset 0 of a partial sector
		assertArrayEquals(new byte[] { 2, 0, 100, 0, 1, 0 }, before);
		// save : the next sector (1), no partial first or last sector, two sectors
		assertArrayEquals(new byte[] { 2, 1, 0, 0, 2, 0 }, save);
		// after : a fresh sector after the save's two (3)
		assertEquals(3, after[1]);
		assertEquals(0, after[3], "the next file starts at the sector's first byte");
	}

	@Test
	@DisplayName("a writable file already on a sector boundary loses nothing")
	void onBoundary() throws Exception {
		FdUtil media = media();
		media.cwrite("DATA", bytes(256, 0xA5), "before");
		byte[] save = media.cwriteWhole("DATA", bytes(256, 0x11), "save");
		assertArrayEquals(new byte[] { 2, 1, 0, 0, 1, 0 }, save);
	}

	@Test
	@DisplayName("a writable payload must be whole sectors")
	void wholeOnly() throws Exception {
		FdUtil media = media();
		Exception e = assertThrows(Exception.class, () -> media.cwriteWhole("DATA", bytes(300, 0), "save"));
		assertTrue(e.getMessage().contains("whole sectors"), e.getMessage());
	}
}
