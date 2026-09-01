package com.widedot.m6809.gamebuilder.config;

import static org.junit.jupiter.api.Assertions.*;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.apache.commons.configuration2.tree.ImmutableNode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Settings;
import com.widedot.m6809.gamebuilder.spi.globals.Compositions;
import com.widedot.m6809.gamebuilder.spi.globals.DirReservations;

/**
 * The table a composition becomes.
 *
 * A state spans directories — the resident scene lives in the library, the
 * stage's in its own — so the table carries, per scene, its file id AND the
 * directory that holds it : the loader mounts a directory before reading the
 * entries of a scene. Both numbers come from the reservations the placement
 * scan computed before anything assembled, which is the only moment they are
 * all known at once.
 */
class CompositionScanTest {

	private static BuildContext ctx(Path dir) {
		BuildContext ctx = new BuildContext(dir.toString(), new Settings(new HashMap<String, String>()));
		ctx.dirReservations.declare(0, reservation("scenes.boot", 150, "scenes.title", 181));
		ctx.dirReservations.declare(1, reservation("scenes.stage1", 303));
		return ctx;
	}

	private static DirReservations.Reservation reservation(Object... nameThenId) {
		Map<String, int[]> idBlocks = new HashMap<String, int[]>();
		Set<String> names = new HashSet<String>();
		for (int i = 0; i < nameThenId.length; i += 2) {
			String name = (String) nameThenId[i];
			idBlocks.put(name, new int[] { (Integer) nameThenId[i + 1], 1 });
			names.add(name);
		}
		return new DirReservations.Reservation(0, 0, idBlocks, names);
	}

	private static ImmutableNode layout(String gen, String... compositions) {
		ImmutableNode.Builder b = new ImmutableNode.Builder().name("layout");
		if (gen != null) {
			b.addAttribute("gencompositions", gen);
		}
		for (String c : compositions) {
			String[] parts = c.split(":");
			ImmutableNode.Builder comp = new ImmutableNode.Builder().name("composition")
					.addAttribute("name", parts[0]);
			if (parts.length > 1) {
				for (String scene : parts[1].split(",")) {
					comp.addChild(new ImmutableNode.Builder().name("scene")
							.addAttribute("name", scene).create());
				}
			}
			b.addChild(comp.create());
		}
		return b.create();
	}

	@Test
	@DisplayName("one table per state : a scene count, then file id and directory per scene")
	void tableCarriesIdAndDirectory(@TempDir Path dir) throws Exception {
		BuildContext ctx = ctx(dir);
		ImmutableNode node = layout("gen/compositions.asm",
				"title:scenes.boot,scenes.title", "stage1:scenes.boot,scenes.stage1");
		CompositionScan.generate(node, ctx, CompositionScan.parse(node, ctx));

		String out = new String(Files.readAllBytes(dir.resolve("gen/compositions.asm")));
		assertTrue(out.contains("compositions.title"));
		assertTrue(out.contains("compositions.stage1"));
		assertTrue(out.contains("fcb   2          ; scenes"));
		assertTrue(out.contains("fdb   181        ; scenes.title"));
		// the stage's scene lives in another directory, and the table says so
		assertTrue(out.contains("fdb   303        ; scenes.stage1"));
		assertTrue(out.contains("fcb   1          ;   directory"));
	}

	@Test
	@DisplayName("nothing is written when the layout asks for no table")
	void generationIsOptIn(@TempDir Path dir) throws Exception {
		BuildContext ctx = ctx(dir);
		ImmutableNode node = layout(null, "title:scenes.boot");
		CompositionScan.generate(node, ctx, CompositionScan.parse(node, ctx));
		assertFalse(Files.exists(dir.resolve("gen/compositions.asm")));
	}

	@Test
	@DisplayName("a scene no directory declares stops the build, not the table")
	void unknownSceneIsRefused(@TempDir Path dir) throws Exception {
		BuildContext ctx = ctx(dir);
		ImmutableNode node = layout("gen/compositions.asm", "title:scenes.boot,scenes.typo");
		List<Compositions.Composition> parsed = CompositionScan.parse(node, ctx);
		Exception e = assertThrows(Exception.class,
				() -> CompositionScan.generate(node, ctx, parsed));
		assertTrue(e.getMessage().contains("scenes.typo"));
	}

	@Test
	@DisplayName("reading twice does not declare twice : the scan reads, the layout declares")
	void parseTouchesNothing(@TempDir Path dir) throws Exception {
		BuildContext ctx = ctx(dir);
		ImmutableNode node = layout(null, "title:scenes.boot");
		CompositionScan.parse(node, ctx);
		CompositionScan.parse(node, ctx);
		assertTrue(ctx.compositions.isEmpty());
	}
}
