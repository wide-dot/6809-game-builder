package com.widedot.m6809.gamebuilder.plugin.scene;

import static org.junit.jupiter.api.Assertions.*;

import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import com.widedot.m6809.gamebuilder.plugin.scene.SceneCheck.Kind;
import com.widedot.m6809.gamebuilder.plugin.scene.SceneCheck.Load;

class SceneChecksTest {

	private SceneCheck scene(String name, Load... loads) {
		SceneCheck s = new SceneCheck(name);
		s.loads.addAll(Arrays.asList(loads));
		return s;
	}

	private Map<String, Integer> sizes(Object... kv) {
		Map<String, Integer> m = new HashMap<String, Integer>();
		for (int i = 0; i < kv.length; i += 2) {
			m.put((String) kv[i], (Integer) kv[i + 1]);
		}
		return m;
	}

	private Map<String, Map<String, int[]>> spans(String entry, int first, int last) {
		Map<String, int[]> one = new HashMap<String, int[]>();
		one.put("zx0", new int[] { first, last });
		Map<String, Map<String, int[]>> m = new HashMap<String, Map<String, int[]>>();
		m.put(entry, one);
		return m;
	}

	@Test
	@DisplayName("a range that must stay in one page is checked against the load address")
	void pageSpan() {
		// the decompressor reads a handful of its own bytes through the direct
		// page, which carries only their low byte : offsets $4F..$5E land in one
		// page at $6100, and across two at $61B0
		List<SceneCheck> scene = Arrays.asList(scene("s",
				new Load("gm", Kind.PLACED, 1, 0x6100, 0x1F00, "gamemode", "f:1")));
		assertTrue(SceneChecks.verify(scene, sizes("gm", 896), spans("gm", 0x4F, 0x5E)).isEmpty());

		List<SceneCheck> moved = Arrays.asList(scene("s",
				new Load("gm", Kind.PLACED, 1, 0x61B0, 0x1F00, "gamemode", "f:1")));
		List<String> errors = SceneChecks.verify(moved, sizes("gm", 896), spans("gm", 0x4F, 0x5E));
		assertEquals(1, errors.size(), errors.toString());
		assertTrue(errors.get(0).contains("page"), errors.get(0));
		assertTrue(errors.get(0).contains("zx0"), errors.get(0));
	}

	@Test
	@DisplayName("an entry with no declared range is left alone")
	void noPageSpan() {
		List<SceneCheck> scene = Arrays.asList(scene("s",
				new Load("gm", Kind.PLACED, 1, 0x61B0, 0x1F00, "gamemode", "f:1")));
		assertTrue(SceneChecks.verify(scene, sizes("gm", 896)).isEmpty());
	}

	@Test
	@DisplayName("a coherent scene passes")
	void coherent() {
		List<String> errors = SceneChecks.verify(Arrays.asList(scene("s",
				new Load("gm", Kind.PLACED, 1, 0x6100, 0x1F00, "gamemode", "f:1"),
				new Load("music", Kind.PLACED, 6, 0x0400, 0x3C00, "ymm.data", "f:2"),
				new Load("iface", Kind.EXPORT_ONLY, 0, 0, null, null, "f:3"))),
				sizes("gm", 896, "music", 4032, "iface", 0));
		assertTrue(errors.isEmpty(), errors.toString());
	}

	@Test
	@DisplayName("a file over its region budget is an error")
	void overBudget() {
		List<String> errors = SceneChecks.verify(Arrays.asList(scene("s",
				new Load("music", Kind.PLACED, 6, 0x0400, 0x0400, "ymm.data", "f:2"))),
				sizes("music", 4032));
		assertEquals(1, errors.size(), errors.toString());
		assertTrue(errors.get(0).contains("4032"), errors.get(0));
		assertTrue(errors.get(0).contains("ymm.data"), errors.get(0));
	}

	@Test
	@DisplayName("two writes of one scene landing on each other is an error")
	void overlapInScene() {
		List<String> errors = SceneChecks.verify(Arrays.asList(scene("s",
				new Load("a", Kind.PLACED, 6, 0x0000, null, null, "f:1"),
				new Load("b", Kind.PLACED, 6, 0x0100, null, null, "f:2"))),
				sizes("a", 0x200, "b", 0x100));
		assertEquals(1, errors.size(), errors.toString());
		assertTrue(errors.get(0).contains("overlap"), errors.get(0));

		// same addresses on different pages : fine
		errors = SceneChecks.verify(Arrays.asList(scene("s",
				new Load("a", Kind.PLACED, 6, 0x0000, null, null, "f:1"),
				new Load("b", Kind.PLACED, 7, 0x0100, null, null, "f:2"))),
				sizes("a", 0x200, "b", 0x100));
		assertTrue(errors.isEmpty(), errors.toString());
	}

	@Test
	@DisplayName("a data file without destination is an error, an empty file placed is not")
	void exportOnlyCoherence() {
		List<String> errors = SceneChecks.verify(Arrays.asList(scene("s",
				new Load("data", Kind.EXPORT_ONLY, 0, 0, null, null, "f:1"))),
				sizes("data", 42));
		assertEquals(1, errors.size(), errors.toString());
		assertTrue(errors.get(0).contains("no destination"), errors.get(0));

		// the mplus-pcm dummyfile trick : an empty file at a raw destination
		errors = SceneChecks.verify(Arrays.asList(scene("s",
				new Load("dummyfile", Kind.PLACED, 0, 0x4000, null, null, "f:1"))),
				sizes("dummyfile", 0));
		assertTrue(errors.isEmpty(), errors.toString());
	}

	@Test
	@DisplayName("a stacked list is laid out sequentially and checked against its budget")
	void bulkBudgetAndLayout() {
		// 3 files of 0x300 : list of 0x900 in a 0x800 region -> error
		List<String> errors = SceneChecks.verify(Arrays.asList(scene("s",
				new Load("a", Kind.BULK, 5, 0x0000, 0x800, "sfx", "f:1"),
				new Load("b", Kind.BULK, 5, 0x0000, 0x800, "sfx", "f:2"),
				new Load("c", Kind.BULK, 5, 0x0000, 0x800, "sfx", "f:3"))),
				sizes("a", 0x300, "b", 0x300, "c", 0x300));
		assertEquals(1, errors.size(), errors.toString());
		assertTrue(errors.get(0).contains("stacked"), errors.get(0));

		// an empty file inside the list contributes nothing (mplus.const case)
		errors = SceneChecks.verify(Arrays.asList(scene("s",
				new Load("a", Kind.BULK, 5, 0x0000, 0x800, "sfx", "f:1"),
				new Load("const", Kind.BULK, 5, 0x0000, 0x800, "sfx", "f:2"),
				new Load("b", Kind.BULK, 5, 0x0000, 0x800, "sfx", "f:3"))),
				sizes("a", 0x400, "const", 0, "b", 0x400));
		assertTrue(errors.isEmpty(), errors.toString());
	}

	@Test
	@DisplayName("a stacked list overlapping a placed load of the same scene is an error")
	void bulkOverlapsPlaced() {
		List<String> errors = SceneChecks.verify(Arrays.asList(scene("s",
				new Load("a", Kind.BULK, 5, 0x0000, null, "sfx", "f:1"),
				new Load("b", Kind.BULK, 5, 0x0000, null, "sfx", "f:2"),
				new Load("solo", Kind.PLACED, 5, 0x0500, null, null, "f:3"))),
				sizes("a", 0x300, "b", 0x300, "solo", 0x100));
		assertEquals(1, errors.size(), errors.toString());
		assertTrue(errors.get(0).contains("overlap"), errors.get(0));
	}
}
