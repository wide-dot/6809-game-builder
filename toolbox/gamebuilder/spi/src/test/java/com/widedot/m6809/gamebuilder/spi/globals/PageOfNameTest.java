package com.widedot.m6809.gamebuilder.spi.globals;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * {@code X$PAGE} with one spelling and two tables (step 5b) : X is a FILE or
 * a SYMBOL, and a name answering in both is refused rather than preferred.
 *
 * These are the messages a build shows, read here on purpose — a guard whose
 * failure has never been read is a guard nobody has read.
 */
class PageOfNameTest {

	@Test
	@DisplayName("a placed file answers, as it always did")
	void fileAnswers() throws Exception {
		StaticLink link = new StaticLink();
		link.place("common.player", 6, 0x0000, "scene.boot");
		assertEquals(6, link.pageOfName("common.player"));
	}

	@Test
	@DisplayName("an exported symbol answers with its provider's page")
	void symbolAnswers() throws Exception {
		StaticLink link = new StaticLink();
		link.place("stage1.tiles.even.1", 0x19, 0x0000, "scene.stage1");
		link.registerExport("adr_stage1.tiles.even_137_ND0", "stage1.tiles.even.1", 0x002E, false);
		assertEquals(0x19, link.pageOfName("adr_stage1.tiles.even_137_ND0"));
	}

	@Test
	@DisplayName("a name that is both is REFUSED, naming the two")
	void ambiguityIsRefused() {
		StaticLink link = new StaticLink();
		link.place("overlay", 8, 0x0000, "scene.boot");          // a file named overlay
		link.registerExport("overlay", "common.hud", 0x1234, false); // and a symbol too
		Exception e = assertThrows(Exception.class, () -> link.pageOfName("overlay"));
		assertTrue(e.getMessage().contains("ambiguous"), e.getMessage());
		assertTrue(e.getMessage().contains("placed file"), e.getMessage());
		assertTrue(e.getMessage().contains("exported symbol"), e.getMessage());
	}

	@Test
	@DisplayName("a name that is neither says so, instead of resolving to nothing")
	void unknownIsNamed() {
		StaticLink link = new StaticLink();
		Exception e = assertThrows(Exception.class, () -> link.pageOfName("nowhere"));
		assertTrue(e.getMessage().contains("nowhere$PAGE"), e.getMessage());
	}
}
