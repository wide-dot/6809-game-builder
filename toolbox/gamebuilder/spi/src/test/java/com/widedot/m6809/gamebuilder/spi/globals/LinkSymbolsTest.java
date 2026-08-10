package com.widedot.m6809.gamebuilder.spi.globals;

import static org.junit.jupiter.api.Assertions.*;

import java.util.Arrays;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class LinkSymbolsTest {

	@Test
	@DisplayName("preseeded ids depend on the names only, not on the order symbols show up")
	void preseededIdsAreStable() throws Exception {
		LinkSymbols first = new LinkSymbols();
		first.preseed(Arrays.asList("alpha", "beta", "gamma"));
		first.add("gamma");
		first.add("alpha");

		LinkSymbols second = new LinkSymbols();
		second.preseed(Arrays.asList("alpha", "beta", "gamma"));
		second.add("alpha");
		second.add("beta");
		second.add("gamma");

		// same names -> same ids, whatever the appearance order
		assertEquals(0, second.add("alpha"));
		assertEquals(1, second.add("beta"));
		assertEquals(2, second.add("gamma"));
		assertEquals(first.add("gamma"), second.add("gamma"));
	}

	@Test
	@DisplayName("a symbol missed by the discovery pass still gets a fresh id")
	void lateSymbolGetsNextId() throws Exception {
		LinkSymbols symbols = new LinkSymbols();
		symbols.preseed(Arrays.asList("alpha", "beta"));
		assertEquals(2, symbols.add("late.comer"));
		assertEquals(2, symbols.add("late.comer"));
	}

	@Test
	@DisplayName("several files may export one name ; the id is shared")
	void duplicateExportsShareTheId() throws Exception {
		LinkSymbols symbols = new LinkSymbols();
		symbols.preseed(Arrays.asList("shared.sym"));
		int first = symbols.export("shared.sym", "file.a");
		int second = symbols.export("shared.sym", "file.b");
		assertEquals(first, second);
	}
}
