package com.widedot.m6809.gamebuilder.spi.globals;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/**
 * Dropping {@code linkdata} from a direntry something still imports used to
 * fail silently : the reference goes through the loader, finds no export and
 * resolves to zero. The build refuses it instead.
 */
public class LinkSymbolsDanglingImportTest {

	/** a unit that imports a symbol some direntry does emit is fine */
	@Test
	void anImportBackedByAnEmittedExportPasses() throws Exception {
		LinkSymbols symbols = new LinkSymbols();
		symbols.beginUnit("common.engine");
		symbols.export("AnimateSprite", "engine.o");
		symbols.add("AnimateSprite");

		assertDoesNotThrow(symbols::checkImportsResolvable);
	}

	/**
	 * The direntry keeps its exports out of the link data — no linkdata, so
	 * {@code export} is never called for it — while another unit still
	 * references the name.
	 */
	@Test
	void anImportWithNoEmittingDirentryIsRejected() throws Exception {
		LinkSymbols symbols = new LinkSymbols();
		symbols.add("AnimateSprite");

		Exception e = assertThrows(Exception.class, symbols::checkImportsResolvable);
		assertTrue(e.getMessage().contains("AnimateSprite"), e.getMessage());
		assertTrue(e.getMessage().contains("no file emits them"), e.getMessage());
	}

	/**
	 * A pruned export is not an emitted one : nothing imports it, so nothing can
	 * dangle either. The check must not confuse the two.
	 */
	@Test
	void aPrunedExportDoesNotCountAsEmittedAndRaisesNothing() throws Exception {
		LinkSymbols symbols = new LinkSymbols();
		symbols.preseedImports(new java.util.HashSet<String>());
		symbols.beginUnit("common.anim");
		symbols.export("Ani_Asd_common", "anim.o");

		assertDoesNotThrow(symbols::checkImportsResolvable);
	}

	/**
	 * A direntry without {@code linkdata} never registers its exports here
	 * at all, so the builder cannot name it — the message has to point at the
	 * cause rather than pretend to know the file.
	 */
	@Test
	void theMessageNamesTheLikelyCause() throws Exception {
		LinkSymbols symbols = new LinkSymbols();
		symbols.add("AwardScore");

		Exception e = assertThrows(Exception.class, symbols::checkImportsResolvable);
		assertTrue(e.getMessage().contains("lost its linkdata"), e.getMessage());
		assertTrue(e.getMessage().contains("bake"), e.getMessage());
	}

	/** every dangling symbol is listed, not just the first one met */
	@Test
	void allDanglingSymbolsAreReported() throws Exception {
		LinkSymbols symbols = new LinkSymbols();
		symbols.add("AwardScore");
		symbols.add("AnimateSprite");

		Exception e = assertThrows(Exception.class, symbols::checkImportsResolvable);
		assertTrue(e.getMessage().contains("AwardScore"), e.getMessage());
		assertTrue(e.getMessage().contains("AnimateSprite"), e.getMessage());
	}
}
