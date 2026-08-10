package com.widedot.m6809.gamebuilder.spi.globals;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/**
 * Export pruning : the discovery pass collects which symbols are actually
 * referenced as EXTERNAL, and the real pass leaves every other export out of
 * the link data — the loader resolves by scanning export tables, so an export
 * nobody references is pure search overhead.
 */
public class LinkSymbolsPruneTest {

	@Test
	void everythingIsEmittedUntilADiscoveryPassSaysOtherwise() throws Exception {
		LinkSymbols symbols = new LinkSymbols();
		symbols.export("api.entry", "a.o");
		assertTrue(symbols.isEmitted("api.entry"));
	}

	@Test
	void onlyImportedExportsSurviveThePrunePass() throws Exception {
		LinkSymbols symbols = new LinkSymbols();
		// discovery : one unit imports api.entry, nobody imports table.raw
		symbols.add("api.entry");
		symbols.export("api.entry", "a.o");
		symbols.export("table.raw", "a.o");

		java.util.Set<String> imported = new java.util.HashSet<String>(symbols.imports);
		symbols.clear();
		symbols.preseedImports(imported);

		assertTrue(symbols.isEmitted("api.entry"));
		assertFalse(symbols.isEmitted("table.raw"));
	}

	@Test
	void exportingDoesNotCountAsImporting() throws Exception {
		LinkSymbols symbols = new LinkSymbols();
		symbols.export("api.entry", "a.o");
		assertFalse(symbols.imports.contains("api.entry"));
		symbols.add("api.entry");
		assertTrue(symbols.imports.contains("api.entry"));
	}

	@Test
	void idsStayDrivenByThePreseedNotByPruning() throws Exception {
		LinkSymbols symbols = new LinkSymbols();
		symbols.preseed(java.util.Arrays.asList("alpha", "beta", "gamma"));
		symbols.preseedImports(java.util.Collections.singleton("gamma"));
		assertEquals(2, symbols.add("gamma"));
		assertEquals(0, symbols.export("alpha", "a.o"));
	}

	@Test
	void clearDisarmsThePruneMode() throws Exception {
		LinkSymbols symbols = new LinkSymbols();
		symbols.preseedImports(java.util.Collections.emptySet());
		assertFalse(symbols.isEmitted("anything"));
		symbols.clear();
		assertTrue(symbols.isEmitted("anything"));
	}
}
