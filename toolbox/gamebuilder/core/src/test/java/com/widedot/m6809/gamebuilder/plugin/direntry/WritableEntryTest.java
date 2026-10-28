package com.widedot.m6809.gamebuilder.plugin.direntry;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** {@code <file writable="true">} : what the direntry accepts and the size it stores. */
class WritableEntryTest {

	@Test
	@DisplayName("the size rounds up to whole sectors, one at least")
	void rounding() {
		assertEquals(256, DirEntryPlugin.wholeSectors(0));
		assertEquals(256, DirEntryPlugin.wholeSectors(1));
		assertEquals(256, DirEntryPlugin.wholeSectors(256));
		assertEquals(512, DirEntryPlugin.wholeSectors(300));
	}

	private static String refused(String codec, boolean link, boolean scene) {
		return assertThrows(Exception.class, () -> DirEntryPlugin.checkWritable("s", codec, link, scene)).getMessage();
	}

	@Test
	@DisplayName("a writable file is raw, without link data, never a scene")
	void refusals() throws Exception {
		assertTrue(refused(null, false, false).contains("codec=\"none\""), "zx0 by default");
		assertTrue(refused("zx0", false, false).contains("codec=\"none\""));
		assertTrue(refused("none", true, false).contains("linkdata"));
		assertTrue(refused("none", false, true).contains("scene"));
		DirEntryPlugin.checkWritable("s", "none", false, false);
	}
}
