package com.widedot.m6809.gamebuilder.config;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Settings;
import com.widedot.m6809.gamebuilder.spi.globals.Cuts;
import com.widedot.m6809.gamebuilder.spi.globals.Regions;

/**
 * Packing file by file (a layout that declares its RAM states) : one largest-first sort
 * over every arena, each file in the lowest run of its arena's zones free
 * of the files it shares a state with.
 */
class ArenaPackerFileTest {

	private static BuildContext ctx(Map<String, Integer> sizes) {
		BuildContext c = new BuildContext(".", new Settings(new java.util.HashMap<String, String>()));
		c.regions.seedFileSizes(sizes);
		return c;
	}

	private static Set<String> states(String... names) {
		return new LinkedHashSet<String>(Arrays.asList(names));
	}

	private static Regions.Region arena(String name) {
		return new Regions.Region(name, 4, 0, null, 1, Arrays.asList(new Regions.Zone(4, 0, 0x4000)), true);
	}

	@Test
	@DisplayName("an act's own file takes the room of a part its state leaves out")
	void ownConflictsNotTheArenas() throws Exception {
		// the zone in both states, a part in act 2's alone, act 1's arena
		// holding a file of act 1 alone and one of both acts. Packed as an
		// arena, act 1's arena starts after the part (its shared file is in
		// act 2's state) and its own file finds no 10 KB : packed file by
		// file, it lies over the part, the most shared placed first
		Map<String, Integer> sizes = new LinkedHashMap<String, Integer>();
		sizes.put("zone", 0x1000);
		sizes.put("part", 0x2000);
		sizes.put("a1", 0x2800);
		sizes.put("a12", 0x0800);
		BuildContext c = ctx(sizes);
		Map<String, List<String>> wanted = new LinkedHashMap<String, List<String>>();
		wanted.put("Z", Arrays.asList("zone"));
		wanted.put("P", Arrays.asList("part"));
		wanted.put("A", Arrays.asList("a1", "a12"));
		Map<String, Regions.Region> regions = new LinkedHashMap<String, Regions.Region>();
		for (String a : wanted.keySet()) {
			regions.put(a, arena(a));
		}
		Map<String, Set<String>> statesOf = new LinkedHashMap<String, Set<String>>();
		statesOf.put("zone", states("act1", "act2"));
		statesOf.put("part", states("act2"));
		statesOf.put("a1", states("act1"));
		statesOf.put("a12", states("act1", "act2"));
		ArenaPacker.packFiles(wanted, regions, c, new LinkedHashMap<String, ArenaPacker.Divisible>(),
				statesOf, new ArrayList<ArenaPacker.Placed>());
		assertArrayEquals(new int[] { 4, 0x0000 }, c.regions.filePlacement("zone"));
		assertArrayEquals(new int[] { 4, 0x1000 }, c.regions.filePlacement("a12"));
		assertArrayEquals(new int[] { 4, 0x1800 }, c.regions.filePlacement("a1"));
		assertArrayEquals(new int[] { 4, 0x1800 }, c.regions.filePlacement("part"), "over a1 : never in RAM with it");
	}

	@Test
	@DisplayName("the most shared first : the zone's files together at the bottom")
	void arenasInTheirOrder() throws Exception {
		// the zone's small file before an act's big one : sorted by size
		// alone, the act's file took the bottom and the zone's went above it
		// for every state ; the most shared first, the zone's comes first
		Map<String, Integer> sizes = new LinkedHashMap<String, Integer>();
		sizes.put("common", 0x0800);
		sizes.put("act", 0x3000);
		BuildContext c = ctx(sizes);
		Map<String, List<String>> wanted = new LinkedHashMap<String, List<String>>();
		wanted.put("Z", Arrays.asList("common"));
		wanted.put("A", Arrays.asList("act"));
		Map<String, Regions.Region> regions = new LinkedHashMap<String, Regions.Region>();
		regions.put("Z", arena("Z"));
		regions.put("A", arena("A"));
		Map<String, Set<String>> statesOf = new LinkedHashMap<String, Set<String>>();
		statesOf.put("common", states("act1", "act2"));
		statesOf.put("act", states("act1"));
		ArenaPacker.packFiles(wanted, regions, c, new LinkedHashMap<String, ArenaPacker.Divisible>(),
				statesOf, new ArrayList<ArenaPacker.Placed>());
		assertArrayEquals(new int[] { 4, 0x0000 }, c.regions.filePlacement("common"));
		assertArrayEquals(new int[] { 4, 0x0800 }, c.regions.filePlacement("act"));
	}

	@Test
	@DisplayName("a file no composition holds shares no byte with anything")
	void unknownStatesConflict() throws Exception {
		Map<String, Integer> sizes = new LinkedHashMap<String, Integer>();
		sizes.put("x", 0x1000);
		sizes.put("y", 0x1000);
		BuildContext c = ctx(sizes);
		Map<String, List<String>> wanted = new LinkedHashMap<String, List<String>>();
		wanted.put("X", Arrays.asList("x"));
		wanted.put("Y", Arrays.asList("y"));
		Map<String, Regions.Region> regions = new LinkedHashMap<String, Regions.Region>();
		regions.put("X", arena("X"));
		regions.put("Y", arena("Y"));
		Map<String, Set<String>> statesOf = new LinkedHashMap<String, Set<String>>();
		statesOf.put("x", states("s1"));
		ArenaPacker.packFiles(wanted, regions, c, new LinkedHashMap<String, ArenaPacker.Divisible>(),
				statesOf, new ArrayList<ArenaPacker.Placed>());
		assertArrayEquals(new int[] { 4, 0x0000 }, c.regions.filePlacement("y"), "no state : placed first");
		assertArrayEquals(new int[] { 4, 0x1000 }, c.regions.filePlacement("x"));
	}

	@Test
	@DisplayName("a collection no run holds whole flows into the runs, one member each")
	void collectionFlowsIntoRuns() throws Exception {
		BuildContext c = ctx(new LinkedHashMap<String, Integer>());
		List<String[]> parts = new ArrayList<String[]>();
		for (int i = 0; i < 4; i++) {
			parts.add(new String[] { "p" + i, "el" + i });
		}
		ArenaPacker.Divisible d = new ArenaPacker.Divisible(parts, new int[] { 0x0C00, 0x0C00, 0x0C00, 0x0C00 },
				"gen", java.util.Collections.emptyMap());
		Map<String, ArenaPacker.Divisible> divisibles = new LinkedHashMap<String, ArenaPacker.Divisible>();
		divisibles.put("tiles", d);
		Map<String, List<String>> wanted = new LinkedHashMap<String, List<String>>();
		wanted.put("A", Arrays.asList("tiles"));
		Map<String, Regions.Region> regions = new LinkedHashMap<String, Regions.Region>();
		regions.put("A", arena("A"));
		Map<String, Set<String>> statesOf = new LinkedHashMap<String, Set<String>>();
		statesOf.put("tiles", states("s1"));
		statesOf.put("fixed", states("s1"));
		List<ArenaPacker.Placed> taken = new ArrayList<ArenaPacker.Placed>();
		taken.add(new ArenaPacker.Placed("fixed", 4, 0x2000, 0x0800));    // a region in the middle
		ArenaPacker.packFiles(wanted, regions, c, divisibles, statesOf, taken);
		List<Cuts.Member> members = c.cuts.members("tiles");
		assertEquals(2, members.size());
		assertEquals(0x0000, members.get(0).address);
		assertEquals(0x2800, members.get(1).address);
	}
}
