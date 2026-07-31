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
		String table = SceneGenerator.generate("s", placed, Collections.emptyList());

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
	@DisplayName("export-only loads become one type %10 block at (0,0)")
	void exportOnlyBlock() throws Exception {
		String table = SceneGenerator.generate("s", Collections.emptyList(),
				Arrays.asList("ym.const", "sn.const"));

		assertTrue(table.contains("fdb   $8000+2"), table);
		assertTrue(table.contains("fcb   0"), table);
		assertTrue(table.contains("fdb   ym.const"), table);
		assertTrue(table.contains("fdb   sn.const"), table);
		assertFalse(table.contains("$4000"), "no placed block expected: " + table);
	}

	@Test
	@DisplayName("mixed scene : placed block first, export-only block second, then end marker")
	void blockOrder() throws Exception {
		String table = SceneGenerator.generate("s",
				Arrays.asList(new Placed(0x01, 0x6100, "gm")),
				Arrays.asList("ym.const"));

		int placedAt = table.indexOf("$4000+1");
		int exportAt = table.indexOf("$8000+1");
		int endAt = table.lastIndexOf("fdb   0 ");
		assertTrue(placedAt >= 0 && exportAt >= 0, table);
		assertTrue(placedAt < exportAt, "the corpus structure is %01 then %10: " + table);
		assertTrue(exportAt < endAt, table);
	}

	@Test
	@DisplayName("an empty scene still carries the end marker")
	void emptyScene() throws Exception {
		String table = SceneGenerator.generate("s", Collections.emptyList(), Collections.emptyList());
		assertTrue(table.contains("fdb   0 "), table);
		assertFalse(table.contains("$4000"), table);
		assertFalse(table.contains("$8000"), table);
	}
}
