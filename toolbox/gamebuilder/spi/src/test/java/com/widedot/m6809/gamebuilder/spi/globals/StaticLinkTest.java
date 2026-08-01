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
	void anUnknownProviderSaysDeclarationOrderMatters() {
		StaticLink link = new StaticLink();
		link.place("assets.tiles", 6, 0x0000, "scenes.main");

		Exception e = assertThrows(Exception.class, () -> link.resolve("adr_t"));
		assertTrue(e.getMessage().contains("declared before"), e.getMessage());
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
