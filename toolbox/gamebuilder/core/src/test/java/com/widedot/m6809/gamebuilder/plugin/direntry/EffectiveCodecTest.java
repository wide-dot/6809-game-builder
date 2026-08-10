package com.widedot.m6809.gamebuilder.plugin.direntry;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * The codec silence (phase 6 of the target-model migration) : compression is
 * the default, the word is the exception. The mapping below is read by three
 * places that must agree — the entry build, the directory's id reservation
 * and the pageset packing — or the reserved==emitted assertion fires.
 */
class EffectiveCodecTest {

	@Test
	@DisplayName("an absent codec means zx0")
	void silenceIsZx0() {
		assertEquals(DirEntryPlugin.ZX0, DirEntryPlugin.effectiveCodec(null));
	}

	@Test
	@DisplayName("none is the explicit raw opt-out, no compression block")
	void noneIsRaw() {
		assertNull(DirEntryPlugin.effectiveCodec("none"));
		assertEquals(1, DirEntryPlugin.blockCount(
				DirEntryPlugin.effectiveCodec("none"), null));
	}

	@Test
	@DisplayName("a named codec passes through and reserves its block")
	void namedCodecPassesThrough() {
		assertEquals(DirEntryPlugin.ZX0, DirEntryPlugin.effectiveCodec("zx0"));
		assertEquals(2, DirEntryPlugin.blockCount(
				DirEntryPlugin.effectiveCodec(null), null));
	}
}
