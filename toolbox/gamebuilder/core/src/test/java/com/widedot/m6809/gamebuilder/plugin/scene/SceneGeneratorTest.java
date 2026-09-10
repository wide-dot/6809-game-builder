package com.widedot.m6809.gamebuilder.plugin.scene;

import static org.junit.jupiter.api.Assertions.*;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import com.widedot.m6809.gamebuilder.plugin.scene.SceneGenerator.Placed;

class SceneGeneratorTest {

	@Test
	@DisplayName("placed loads become one type %01 block of explicit triplets")
	void placedBlock() throws Exception {
		List<Placed> placed = Arrays.asList(
				new Placed(0x01, 0x6100, "assets.gm.title"),
				new Placed(0x06, 0x0400, "assets.sounds.title.ymm"));
		String table = SceneGenerator.generate("s", placed, Collections.emptyList(), null);

		assertTrue(table.contains("fdb   $4000+2"), table);
		assertTrue(table.contains("fcb   $01"), table);
		assertTrue(table.contains("fdb   $6100"), table);
		assertTrue(table.contains("fdb   assets.gm.title"), table);
		assertTrue(table.contains("fcb   $06"), table);
		assertTrue(table.contains("fdb   $0400"), table);
		assertFalse(table.contains("$8000"), "no export-only block expected: " + table);
		assertTrue(table.trim().endsWith("fdb   0                        ; end marker"), table);
	}

	@Test
	@DisplayName("export-only loads become %11 blocks at (0,0) — one per run of consecutive ids")
	void exportOnlyBlock() throws Exception {
		// no id table : nothing is known to chain, one block of one per file
		String table = SceneGenerator.generate("s", Collections.emptyList(),
				Arrays.asList("ym.const", "sn.const"), null);

		assertEquals(2, count(table, "fdb   $C000+1"), table);
		assertTrue(table.contains("fcb   $00"), table);
		assertTrue(table.contains("fdb   $0000"), table);
		assertTrue(table.contains("fdb   ym.const"), table);
		assertTrue(table.contains("fdb   sn.const"), table);
		assertFalse(table.contains("$4000"), "no placed block expected: " + table);
		assertFalse(table.contains("$8000"), "the %10 encoding is gone (08/09/2026): " + table);
	}

	@Test
	@DisplayName("mixed scene : placed block first, export-only block second, then end marker")
	void blockOrder() throws Exception {
		String table = SceneGenerator.generate("s",
				Arrays.asList(new Placed(0x01, 0x6100, "gm")),
				Arrays.asList("ym.const"), null);

		int placedAt = table.indexOf("$4000+1");
		int exportAt = table.indexOf("$C000+1");
		int endAt = table.lastIndexOf("fdb   0 ");
		assertTrue(placedAt >= 0 && exportAt >= 0, table);
		assertTrue(placedAt < exportAt, "the corpus structure is %01 then %11: " + table);
		assertTrue(exportAt < endAt, table);
	}

	@Test
	@DisplayName("a chained id list is one %11 block ; a broken chain is one %11 block per run")
	void chainEncoding() throws Exception {
		java.util.Map<String, int[]> ids = new java.util.HashMap<String, int[]>();
		ids.put("pad.a", new int[] { 10, 2 });   // linked : 2 blocks
		ids.put("pad.b", new int[] { 12, 2 });
		ids.put("pad.c", new int[] { 14, 2 });

		String table = SceneGenerator.generate("s", Collections.emptyList(),
				Arrays.asList("pad.a", "pad.b", "pad.c"), ids);
		assertTrue(table.contains("fdb   $C000+3"), table);
		assertTrue(table.contains("fdb   pad.a"), table);
		assertFalse(table.contains("fdb   pad.b"), "only the start id is emitted: " + table);

		// declaration order changed : no two ids follow each other, three runs
		// of one — each its own %11 block, every start id emitted (the %10
		// fallback is gone, 08/09/2026)
		table = SceneGenerator.generate("s", Collections.emptyList(),
				Arrays.asList("pad.b", "pad.a", "pad.c"), ids);
		assertEquals(3, count(table, "fdb   $C000+1"), table);
		assertFalse(table.contains("$C000+3"), table);
		assertFalse(table.contains("$8000"), table);
		assertTrue(table.contains("fdb   pad.b"), table);
		assertTrue(table.contains("fdb   pad.a"), table);
		assertTrue(table.contains("fdb   pad.c"), table);

		// a partial chain : a run of two, then one
		table = SceneGenerator.generate("s", Collections.emptyList(),
				Arrays.asList("pad.a", "pad.b", "pad.a"), ids);
		assertTrue(table.contains("fdb   $C000+2"), table);
		assertEquals(1, count(table, "fdb   $C000+1"), table);

		// a single file is a %11 block of one
		table = SceneGenerator.generate("s", Collections.emptyList(),
				Arrays.asList("pad.a"), ids);
		assertTrue(table.contains("fdb   $C000+1"), table);
	}

	/** occurrences of a needle in the table */
	private static int count(String table, String needle) {
		int n = 0;
		for (int i = table.indexOf(needle); i >= 0; i = table.indexOf(needle, i + 1)) {
			n++;
		}
		return n;
	}

	@Test
	@DisplayName("an empty scene still carries the end marker")
	void emptyScene() throws Exception {
		String table = SceneGenerator.generate("s", Collections.emptyList(), Collections.emptyList(), null);
		assertTrue(table.contains("fdb   0 "), table);
		assertFalse(table.contains("$4000"), table);
		assertFalse(table.contains("$C000"), table);
	}
}
