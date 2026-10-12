package com.widedot.m6809.gamebuilder.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

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
import com.widedot.m6809.gamebuilder.spi.globals.Regions;

/**
 * The hole, the packer's last resort before refusing a file : the room
 * under a zone's tail that holds only files never in RAM with this one.
 */
class ArenaPackerHoleTest {

	private static BuildContext ctx() {
		return new BuildContext(".", new Settings(new java.util.HashMap<String, String>()));
	}

	private static Set<String> states(String... names) {
		return new LinkedHashSet<String>(Arrays.asList(names));
	}

	@Test
	@DisplayName("a file takes the room of another act's files, never its own state's nor its arena's")
	void holeUnderTheTail() {
		Regions.Zone z = new Regions.Zone(4, 0x0000, 0x4000);
		Regions.Region arena = new Regions.Region("act2", 4, 0x0000, null, 1, Arrays.asList(z), true);
		Map<String, Set<String>> statesOf = new LinkedHashMap<String, Set<String>>();
		statesOf.put("shared", states("act1", "act2"));   // in RAM with the new file
		statesOf.put("other", states("act1"));             // another act's alone
		statesOf.put("late", states("act1", "act2"));      // the tail starts after it
		statesOf.put("new", states("act2"));
		statesOf.put("own", states("act2"));
		List<ArenaPacker.Placed> taken = new ArrayList<ArenaPacker.Placed>();
		taken.add(new ArenaPacker.Placed("shared", 4, 0x0000, 0x0800));
		taken.add(new ArenaPacker.Placed("other", 4, 0x0800, 0x2000));
		taken.add(new ArenaPacker.Placed("own", 4, 0x0800, 0x0400));
		taken.add(new ArenaPacker.Placed("late", 4, 0x3F00, 0x0100));
		int[] tailStart = { 0x4000 };
		List<String> arenaFiles = Arrays.asList("own", "new");
		assertTrue(ArenaPacker.hole(arena, "new", 0x1000, arenaFiles, tailStart, statesOf, taken, ctx()));
		ArenaPacker.Placed p = taken.get(taken.size() - 1);
		assertEquals("new", p.file);
		assertEquals(0x0C00, p.address, "after 'shared' (co-resident) and 'own' (its arena), over 'other'");

		// no run long enough : refused, nothing placed
		int before = taken.size();
		assertFalse(ArenaPacker.hole(arena, "big", 0x3000, arenaFiles, tailStart, statesOf, taken, ctx()));
		assertEquals(before, taken.size());
	}
}
