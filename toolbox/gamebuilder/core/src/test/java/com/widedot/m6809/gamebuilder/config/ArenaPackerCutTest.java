package com.widedot.m6809.gamebuilder.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.globals.Cuts;
import com.widedot.m6809.gamebuilder.spi.configuration.Settings;
import com.widedot.m6809.gamebuilder.spi.globals.Regions;

/**
 * The cut, the fallback of the single sort (5c) : a collection that does not
 * fit whole flows into the zones' free tails — one member per tail used, as
 * big as the tail allows, elements in declaration order. The tails decide
 * the cut, never a setting. Retargeted from the pageset flow tests when the
 * element was retired ; the scenarios are the same behaviours.
 */
class ArenaPackerCutTest {

	private static BuildContext ctx() {
		java.util.Map<String, String> values = new java.util.HashMap<String, String>();
		return new BuildContext(".", new Settings(values));
	}

	private static ArenaPacker.Divisible divisible(int... sizes) {
		List<String[]> parts = new ArrayList<String[]>();
		for (int i = 0; i < sizes.length; i++) {
			parts.add(new String[] { "path" + i, "el" + i });
		}
		return new ArenaPacker.Divisible(parts, sizes, "gen",
				java.util.Collections.emptyMap());
	}

	/** an arena whose zones' free room equals the given runs, page = index+4 */
	private static Regions.Region arena(int... runs) {
		List<Regions.Zone> zones = new ArrayList<Regions.Zone>();
		for (int i = 0; i < runs.length; i++) {
			zones.add(new Regions.Zone(4 + i, 0x1000, runs[i]));
		}
		return new Regions.Region("a", 4, 0x1000, null, runs.length, zones, true);
	}

	@Test
	@DisplayName("the manual's example : two chunks, not five — the tails decide")
	void tailsDecideTheCut() throws Exception {
		// a 9834 byte tail, two untouched pages ; 17810 bytes of elements
		// flow as two chunks, the third zone never used
		int[] sizes = new int[244];
		Arrays.fill(sizes, 73);
		sizes[243] = 71; // 243*73+71 = 17810
		BuildContext c = ctx();
		int[] free = { 9834, 16384, 16384 };
		ArenaPacker.cut(arena(9834, 16384, 16384), "tiles", divisible(sizes), free, c);
		List<Cuts.Member> members = c.cuts.members("tiles");
		assertEquals(2, members.size());
		assertEquals(4, members.get(0).page);
		assertEquals(5, members.get(1).page);
		// the untouched zone survives whole for the next file of the sort
		assertEquals(16384, free[2]);
	}

	@Test
	@DisplayName("a tail under the threshold is left empty, not crumbled into")
	void thresholdLeavesSmallTailsEmpty() throws Exception {
		BuildContext c = ctx();
		int[] free = { 200, 16384 };
		ArenaPacker.cut(arena(200, 16384), "s", divisible(100, 100), free, c);
		// one tail held everything : a whole placement, no members
		assertNull(c.cuts.members("s"));
		int[] at = c.regions.filePlacement("s");
		assertNotNull(at);
		assertEquals(5, at[0]);
		assertEquals(200, free[0]);
	}

	@Test
	@DisplayName("a consumed tail's remainder stays available for the next file")
	void consumedTailRemainderStaysAvailable() throws Exception {
		// 300+300 fill zone one to 600 of 1000 ; 500 opens zone two — and the
		// 400 bytes left in zone one are still free for the sort's next file
		BuildContext c = ctx();
		int[] free = { 1000, 16384 };
		ArenaPacker.cut(arena(1000, 16384), "s", divisible(300, 300, 500), free, c);
		assertEquals(2, c.cuts.members("s").size());
		assertEquals(400, free[0]);
	}

	@Test
	@DisplayName("a tail too small for the element at hand survives whole")
	void skippedTailSurvivesWhole() throws Exception {
		BuildContext c = ctx();
		int[] free = { 500, 16384 };
		ArenaPacker.cut(arena(500, 16384), "s", divisible(800), free, c);
		assertNull(c.cuts.members("s"));
		assertEquals(5, c.regions.filePlacement("s")[0]);
		assertEquals(500, free[0]);
	}

	@Test
	@DisplayName("an element bigger than the roomiest free run is a named error")
	void oversizedElementIsANamedError() {
		Exception e = assertThrows(Exception.class, () -> ArenaPacker.cut(
				arena(16384), "s", divisible(20000), new int[] { 16384 }, ctx()));
		assertTrue(e.getMessage().contains("el0"), e.getMessage());
	}

	@Test
	@DisplayName("a collection that does not fit reports the shortfall")
	void overflowReportsTheShortfall() {
		Exception e = assertThrows(Exception.class, () -> ArenaPacker.cut(
				arena(1000), "s", divisible(900, 900, 900), new int[] { 1000 }, ctx()));
		assertTrue(e.getMessage().contains("1800"), e.getMessage());
	}
}
