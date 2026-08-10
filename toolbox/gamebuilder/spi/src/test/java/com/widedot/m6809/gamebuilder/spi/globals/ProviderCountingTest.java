package com.widedot.m6809.gamebuilder.spi.globals;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * The naked provider-counting routing (author's arbitration, 2026-08-10) :
 * no reachability or co-location analysis anywhere. Several files may export
 * one name — the loader's first-match scan decides at run time — and the
 * bake refuses to resolve such a name at build time, whoever asks. The only
 * multi-provider case that resolves is several exports of the same absolute
 * value : one answer, whoever provides it.
 */
class ProviderCountingTest {

	@Test
	@DisplayName("several files may export one name ; they share the link id")
	void duplicatesAreAFact() throws Exception {
		LinkSymbols symbols = new LinkSymbols();
		symbols.beginUnit("stage1");
		int first = symbols.export("Obj_Index_Page", "main.o");
		symbols.beginUnit("stage2");
		int second = symbols.export("Obj_Index_Page", "main.o");
		assertEquals(first, second);
	}

	@Test
	@DisplayName("a single placed provider resolves at build time")
	void singleProviderResolves() throws Exception {
		StaticLink link = new StaticLink();
		link.place("stage1.tiles", 4, 0x0000, "scene.one");
		link.registerExport("adr_stage1.tiles_12_ND0", "stage1.tiles", 0x065C, false);
		assertEquals(0x065C, link.resolve("adr_stage1.tiles_12_ND0"));
	}

	@Test
	@DisplayName("several providers refuse a build-time value, whoever asks")
	void multiProviderStaysLinked() {
		StaticLink link = new StaticLink();
		link.place("stage1", 4, 0xA000, "scene.one");
		link.place("stage2", 4, 0xA000, "scene.two");
		link.registerExport("wave.data", "stage1", 0x0100, false);
		link.registerExport("wave.data", "stage2", 0x0200, false);
		link.setCurrentConsumer("common.engine");
		Exception e = assertThrows(Exception.class, () -> link.resolve("wave.data"));
		assertTrue(e.getMessage().contains("several providers"), e.getMessage());
	}

	@Test
	@DisplayName("identical absolute constants are one value whoever provides them")
	void sameAbsoluteValueResolves() throws Exception {
		StaticLink link = new StaticLink();
		link.registerExport("ymm.NO_LOOP", "stage1", 0x0000, true);
		link.registerExport("ymm.NO_LOOP", "stage2", 0x0000, true);
		assertEquals(0x0000, link.resolve("ymm.NO_LOOP"));
	}

	@Test
	@DisplayName("differing absolute constants refuse like any multi-provider name")
	void differingAbsolutesStayLinked() {
		StaticLink link = new StaticLink();
		link.registerExport("stage.length", "stage1", 132, true);
		link.registerExport("stage.length", "stage2", 96, true);
		assertThrows(Exception.class, () -> link.resolve("stage.length"));
	}
}
