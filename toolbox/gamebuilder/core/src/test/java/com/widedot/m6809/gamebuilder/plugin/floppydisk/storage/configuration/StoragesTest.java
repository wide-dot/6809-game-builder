package com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration;

import static org.junit.jupiter.api.Assertions.*;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class StoragesTest {

	@org.junit.jupiter.api.io.TempDir
	Path dir;

	private static final String FD640 =
		"<configuration>\n" +
		"  <rom model=\"t2\">\n" +
		"    <segment pages=\"128\" pageSize=\"0x4000\" org=\"0\"/>\n" +
		"  </rom>\n" +
		"  <floppydisk model=\"fd640\">\n" +
		"    <segment faces=\"2\" tracks=\"80\" sectors=\"16\" sectorSize=\"256\"/>\n" +
		"    <interleave softskip=\"2\" softskew=\"4\" hardskip=\"7\"/>\n" +
		"    <fat sectorperblock=\"8\" nblocks=\"160\" sectorsize=\"255\" fatstart=\"129\" dirstart=\"512\" ndirentries=\"112\"/>\n" +
		"    <section name=\"BOOT\" track=\"0\" face=\"0\" sector=\"1\"/>\n" +
		"    <section name=\"INDEX\" track=\"0\" face=\"1\" sector=\"4\"/>\n" +
		"  </floppydisk>\n" +
		"</configuration>\n";

	private Path write(String content) throws Exception {
		Path f = dir.resolve("storage.xml");
		Files.write(f, content.getBytes(StandardCharsets.UTF_8));
		return f;
	}

	@Test
	@DisplayName("a storage file loads : geometry, interleave, sections ; rom entries are ignored")
	void loads() throws Exception {
		Storages storages = new Storages(write(FD640).toString());

		Storage fd640 = storages.get("fd640");
		assertNotNull(fd640);
		assertEquals(2, fd640.segment.faces);
		assertEquals(80, fd640.segment.tracks);
		assertEquals(16, fd640.segment.sectors);
		assertEquals(256, fd640.segment.sectorSize);
		assertEquals(80 * 16 * 256, fd640.segment.tracksSize);
		assertEquals(7, fd640.interleave.hardskip);
		assertEquals(2, fd640.interleave.softskip);
		assertEquals(4, fd640.interleave.softskew);
		// the fat geometry is read with the right keys now (sectorperblock
		// used to silently come out as 0)
		assertEquals(8, fd640.fat.sectorPerBlock);
		assertEquals(160, fd640.fat.nBlocks);
		assertEquals(4, fd640.sections.get("INDEX").sector);
		assertEquals(1, fd640.sections.get("INDEX").face);
	}

	@Test
	@DisplayName("a missing geometry attribute is an error with its source position")
	void missingAttribute() throws Exception {
		Path f = write(FD640.replace(" tracks=\"80\"", ""));
		Exception e = assertThrows(Exception.class, () -> new Storages(f.toString()));
		assertTrue(e.getMessage().contains("tracks"), e.getMessage());
		assertTrue(e.getMessage().contains("storage.xml:6"), e.getMessage());
	}

	@Test
	@DisplayName("a non numeric value is an error with its source position")
	void badNumber() throws Exception {
		Path f = write(FD640.replace("sectors=\"16\"", "sectors=\"beaucoup\""));
		Exception e = assertThrows(Exception.class, () -> new Storages(f.toString()));
		assertTrue(e.getMessage().contains("beaucoup"), e.getMessage());
		assertTrue(e.getMessage().contains("storage.xml:6"), e.getMessage());
	}

	@Test
	@DisplayName("a duplicated or missing mandatory child is an error")
	void mandatoryChildren() throws Exception {
		Path f = write(FD640.replace("<interleave softskip=\"2\" softskew=\"4\" hardskip=\"7\"/>", ""));
		Exception e = assertThrows(Exception.class, () -> new Storages(f.toString()));
		assertTrue(e.getMessage().contains("interleave"), e.getMessage());
	}
}
