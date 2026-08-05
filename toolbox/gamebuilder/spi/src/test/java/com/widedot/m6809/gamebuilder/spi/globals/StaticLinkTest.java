package com.widedot.m6809.gamebuilder.spi.globals;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/**
 * The registry behind the *.static sections : placements collected from the
 * scenes, export offsets registered as direntries build, and the resolution
 * rules a static reference lives by. A promise with no fallback — every
 * failure here has to be an error that names its cause.
 */
public class StaticLinkTest {

	@Test
	void resolvesARelativeExportAgainstItsPlacement() throws Exception {
		StaticLink link = new StaticLink();
		link.place("assets.tiles", 6, 0x0000, "scenes.main");
		link.registerExport("adr_tile0_ND0", "assets.tiles", 0x01C2, false);

		assertEquals(0x01C2, link.resolve("adr_tile0_ND0"));
		assertEquals(6, link.resolvePage("assets.tiles"));
	}

	@Test
	void aPlacedRegionAddsItsAddress() throws Exception {
		StaticLink link = new StaticLink();
		link.place("assets.gm", 1, 0x6100, "scenes.main");
		link.registerExport("main.table", "assets.gm", 0x0042, false);

		assertEquals(0x6142, link.resolve("main.table"));
	}

	@Test
	void anAbsoluteExportStandsAlone() throws Exception {
		StaticLink link = new StaticLink();
		// no placement at all : a constant does not need one
		link.registerExport("screen.WIDTH", "assets.gm", 160, true);

		assertEquals(160, link.resolve("screen.WIDTH"));
	}

	@Test
	void twoAgreeingScenesAreNotAConflict() throws Exception {
		StaticLink link = new StaticLink();
		link.place("assets.tiles", 6, 0x0000, "scenes.main");
		link.place("assets.tiles", 6, 0x0000, "scenes.other");
		link.registerExport("adr_t", "assets.tiles", 0x0010, false);

		assertEquals(0x0010, link.resolve("adr_t"));
	}

	@Test
	void twoDestinationsAreAnErrorThatNamesBothScenes() {
		StaticLink link = new StaticLink();
		link.place("assets.tiles", 6, 0x0000, "scenes.main");
		link.place("assets.tiles", 7, 0x2000, "scenes.other");
		link.registerExport("adr_t", "assets.tiles", 0x0010, false);

		Exception e = assertThrows(Exception.class, () -> link.resolve("adr_t"));
		assertTrue(e.getMessage().contains("scenes.main"), e.getMessage());
		assertTrue(e.getMessage().contains("scenes.other"), e.getMessage());
	}

	@Test
	void anUnknownProviderNamesTheSymbolAndTheWorkaround() {
		StaticLink link = new StaticLink();
		link.place("assets.tiles", 6, 0x0000, "scenes.main");

		// with the discovery harvest, declaration order no longer decides ;
		// the message keeps the ordering workaround for the case where the
		// discovery pass itself stopped early
		Exception e = assertThrows(Exception.class, () -> link.resolve("adr_t"));
		assertTrue(e.getMessage().contains("adr_t"), e.getMessage());
		assertTrue(e.getMessage().contains("before its consumer"), e.getMessage());
	}

	/**
	 * Run-time alternatives share export names by design — each stage exports
	 * its wave. The consumer decides : a stage baking its own wave binds to
	 * the one provider it can see at run time, because every scene that loads
	 * the other stage's wave also loads the other stage, which evicts it.
	 */
	@Test
	void aMultiProviderSymbolBindsToTheOnlyReachableProvider() throws Exception {
		StaticLink link = new StaticLink();
		// the two stages are alternatives at the same destination
		link.place("stage1", 1, 0x8000, "scenes.boot");
		link.place("stage1", 1, 0x8000, "scenes.stage1");
		link.place("stage2", 1, 0x8000, "scenes.stage2");
		// each carries its own wave provider
		link.place("stage1.wave", 6, 0x0000, "scenes.boot");
		link.place("stage1.wave", 6, 0x0000, "scenes.stage1");
		link.place("stage2.wave", 6, 0x0000, "scenes.stage2");
		link.registerExport("wave.data", "stage1.wave", 0x0100, false);
		link.registerExport("wave.data", "stage2.wave", 0x0200, false);

		link.setCurrentConsumer("stage1");
		assertEquals(0x0100, link.resolve("wave.data"));
		link.setCurrentConsumer("stage2");
		assertEquals(0x0200, link.resolve("wave.data"));
	}

	/**
	 * A resident consumer sees every alternative across the scene sequence,
	 * so no single build-time value exists. This must refuse — resolving
	 * against whichever registered last would freeze the swap.
	 */
	@Test
	void aResidentConsumerOfAlternativesIsRefused() {
		StaticLink link = new StaticLink();
		link.place("engine", 1, 0x6100, "scenes.boot");
		link.place("stage1", 1, 0x8000, "scenes.boot");
		link.place("stage2", 1, 0x8000, "scenes.stage2");
		link.registerExport("Obj_Index_Page", "stage1", 0x0010, false);
		link.registerExport("Obj_Index_Page", "stage2", 0x0012, false);

		link.setCurrentConsumer("engine");
		Exception e = assertThrows(Exception.class, () -> link.resolve("Obj_Index_Page"));
		assertTrue(e.getMessage().contains("stage1"), e.getMessage());
		assertTrue(e.getMessage().contains("stage2"), e.getMessage());
		assertTrue(e.getMessage().contains("load-time linked"), e.getMessage());
	}

	/** two alternatives exporting the same absolute constant are one value */
	@Test
	void identicalAbsoluteConstantsResolveWhoeverProvides() throws Exception {
		StaticLink link = new StaticLink();
		link.registerExport("music.LOOP", "stage1.music", 0x0001, true);
		link.registerExport("music.LOOP", "stage2.music", 0x0001, true);

		link.setCurrentConsumer("engine");
		assertEquals(0x0001, link.resolve("music.LOOP"));
	}

	/** the discovery harvest : preseeded exports resolve before any direntry builds */
	@Test
	void preseededExportsResolveWhateverTheDeclarationOrder() throws Exception {
		StaticLink discovery = new StaticLink();
		discovery.registerExport("provider.entry", "provider", 0x006D, false);

		StaticLink real = new StaticLink();
		real.place("provider", 4, 0x2400, "scenes.main");
		real.preseed(discovery.snapshot());

		// no registerExport ran in the real pass yet : the consumer builds first
		assertEquals(0x246D, real.resolve("provider.entry"));
	}

	@Test
	void anUnplacedProviderIsAnError() {
		StaticLink link = new StaticLink();
		link.registerExport("adr_t", "assets.tiles", 0x0010, false);

		Exception e = assertThrows(Exception.class, () -> link.resolve("adr_t"));
		assertTrue(e.getMessage().contains("no scene loads"), e.getMessage());
	}

	@Test
	void aBulkMemberCarriesItsReason() {
		StaticLink link = new StaticLink();
		link.placeConflict("assets.stack", "scene s loads it into the bulk region 'perm'");
		link.registerExport("stack.begin", "assets.stack", 0, false);

		Exception e = assertThrows(Exception.class, () -> link.resolve("stack.begin"));
		assertTrue(e.getMessage().contains("bulk"), e.getMessage());
	}
}
