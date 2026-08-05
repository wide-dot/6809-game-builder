package com.widedot.m6809.gamebuilder.plugin.scene;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

import com.widedot.m6809.gamebuilder.spi.globals.LinkReport;
import com.widedot.m6809.gamebuilder.spi.globals.RamMap;

/**
 * The pool map is read to answer one question — can this scene still be linked
 * — so what it must get right is the size the ALLOCATOR reserves, not the size
 * the link data occupies. The difference between the two is what made a build
 * that looked comfortably inside budget run out of memory on the machine.
 */
public class PoolMapReportTest {

	private static LinkReport.Entry entry(String name, int bytes) {
		return new LinkReport.Entry(name, bytes, 0, 0, 0, 0, 0, 0, 0, true);
	}

	private static RamMap.Load load(String name) {
		return new RamMap.Load(name, "somewhere", 1, 0x0000, 0, false);
	}

	/**
	 * Mirrors engine/memory/malloc/tlsf.asm : a 4 byte header, a floor of one
	 * whole block header, and rounding up to the size class (16 per power of
	 * two). 2266 bytes of link data really costs 2304.
	 */
	@Test
	void whatTlsfReservesIsMoreThanWhatIsAsked() {
		assertEquals(8, PoolMapReport.served(1));
		assertEquals(8, PoolMapReport.served(4));
		// 2266 + 4 = 2270 -> class 2048, granularity 128 -> 2304
		assertEquals(2304, PoolMapReport.served(2266));
		// 918 + 4 = 922 -> class 512, granularity 32 -> 928
		assertEquals(928, PoolMapReport.served(918));
	}

	@Test
	void aSceneIsTotalledAgainstTheDeclaredPool() {
		RamMap map = new RamMap();
		map.record("scenes.boot", load("engine"));
		map.record("scenes.boot", load("player"));
		LinkReport link = new LinkReport();
		link.add(entry("engine", 2266));
		link.add(entry("player", 918));

		String report = PoolMapReport.render("fd", map, link, 0x1000);

		assertTrue(report.contains("scenes.boot"), report);
		// raw 3184, served 2304 + 928 = 3232, out of 4096
		assertTrue(report.matches("(?s).*3184\\s+3232\\s+total.*"), report);
		assertTrue(report.contains("78% of the pool"), report);
		assertTrue(report.contains("864 bytes left"), report);
	}

	/** the failure this report exists to make visible, before the machine hangs */
	@Test
	void aSceneThatCannotBeLinkedSaysSo() {
		RamMap map = new RamMap();
		map.record("scenes.boot", load("engine"));
		LinkReport link = new LinkReport();
		link.add(entry("engine", 2266));

		String report = PoolMapReport.render("fd", map, link, 0x800);

		assertTrue(report.contains("OVER BUDGET"), report);
	}

	/**
	 * A file with no link block costs the pool nothing, and a file a scene
	 * loads twice is indexed once. Counting either would overstate the demand
	 * and send someone hunting for room that is not missing.
	 */
	@Test
	void bakedAndDuplicateLoadsAreNotCounted() {
		RamMap map = new RamMap();
		map.record("scenes.boot", load("engine"));
		map.record("scenes.boot", load("engine"));
		map.record("scenes.boot", load("tiles"));
		LinkReport link = new LinkReport();
		link.add(entry("engine", 2266));
		link.add(entry("tiles", 0));

		String report = PoolMapReport.render("fd", map, link, 0x1000);

		assertTrue(report.contains("1 indexed file(s)"), report);
		assertFalse(report.contains("tiles"), report);
		assertTrue(report.matches("(?s).*2266\\s+2304\\s+total.*"), report);
	}

	/**
	 * The loader's own default is an expression, not a literal. A target that
	 * leaves it alone still gets its per-scene totals — only the budget column
	 * is dropped.
	 */
	@Test
	void withoutADeclaredPoolTheTotalsStillStand() {
		RamMap map = new RamMap();
		map.record("scenes.boot", load("engine"));
		LinkReport link = new LinkReport();
		link.add(entry("engine", 2266));

		String report = PoolMapReport.render("fd", map, link, -1);

		assertTrue(report.contains("is not defined by this target"), report);
		assertTrue(report.matches("(?s).*2266\\s+2304\\s+total.*"), report);
		assertFalse(report.contains("% of the pool"), report);
	}

	/**
	 * The figure is a floor : the directory, the scene file and the slot table
	 * share the pool. Saying so in the report is the difference between a
	 * number someone trusts and a number someone checks.
	 */
	@Test
	void theReportSaysWhatItDoesNotCount() {
		RamMap map = new RamMap();
		map.record("scenes.boot", load("engine"));
		LinkReport link = new LinkReport();
		link.add(entry("engine", 2266));

		String report = PoolMapReport.render("fd", map, link, 0x1000);

		assertTrue(report.contains("NOT counted"), report);
		assertTrue(report.contains("tlsf.err"), report);
	}
}
