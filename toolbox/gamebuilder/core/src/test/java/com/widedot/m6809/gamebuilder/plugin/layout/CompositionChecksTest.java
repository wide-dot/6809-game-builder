package com.widedot.m6809.gamebuilder.plugin.layout;

import static org.junit.jupiter.api.Assertions.*;

import java.util.Arrays;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Settings;
import com.widedot.m6809.gamebuilder.spi.globals.Compositions;
import com.widedot.m6809.gamebuilder.spi.globals.RamMap;

/**
 * The declared RAM states.
 *
 * The case that pays for the whole mechanism : two files no single scene
 * loads together, given the same bytes by the packer because it read
 * "composition = scene", while the game keeps both in memory. Declaring the
 * composition is what turns that into a build error instead of a stale link
 * slot patched into a tile's code.
 */
class CompositionChecksTest {

	private static BuildContext context() {
		return new BuildContext(".", new Settings(new java.util.HashMap<String, String>()));
	}

	private static void load(BuildContext ctx, String scene, String file, int page, int address,
			int size) {
		ctx.ramMap.ensure(scene);
		ctx.ramMap.record(scene, new RamMap.Load(file, "arena", page, address, size));
	}

	private static void compose(BuildContext ctx, String name, String... scenes) throws Exception {
		ctx.compositions.declare(new Compositions.Composition(name, Arrays.asList(scenes), "test"));
	}

	@Test
	@DisplayName("silent when nothing is declared : the mechanism is opt-in")
	void optIn() throws Exception {
		BuildContext ctx = context();
		load(ctx, "scenes.one", "a", 26, 0x0000, 0x1000);
		load(ctx, "scenes.two", "b", 26, 0x0000, 0x1000);
		CompositionChecks.verify(ctx);
	}

	@Test
	@DisplayName("two files of one composition may not share bytes")
	void overlapInsideAComposition() throws Exception {
		BuildContext ctx = context();
		load(ctx, "scenes.stage", "stage.tiles", 26, 0x0000, 0x1C6A);
		load(ctx, "scenes.lot", "lib.enemy", 26, 0x0000, 0x1955);
		compose(ctx, "stage", "scenes.stage", "scenes.lot");
		Exception e = assertThrows(Exception.class, () -> CompositionChecks.verify(ctx));
		assertTrue(e.getMessage().contains("stage.tiles"));
		assertTrue(e.getMessage().contains("lib.enemy"));
		assertTrue(e.getMessage().contains("overlap on page 26"));
	}

	@Test
	@DisplayName("the same bytes in two compositions that never meet are alternatives")
	void alternativesStayLegal() throws Exception {
		BuildContext ctx = context();
		load(ctx, "scenes.stage1", "stage1.tiles", 26, 0x0000, 0x1C6A);
		load(ctx, "scenes.stage2", "stage2.tiles", 26, 0x0000, 0x1C6A);
		compose(ctx, "stage1", "scenes.stage1");
		compose(ctx, "stage2", "scenes.stage2");
		CompositionChecks.verify(ctx);
	}

	@Test
	@DisplayName("a scene named by no composition is a build error")
	void everySceneMustBeNamed() throws Exception {
		BuildContext ctx = context();
		load(ctx, "scenes.stage1", "stage1.tiles", 26, 0x0000, 0x1000);
		load(ctx, "scenes.lot", "lib.enemy", 27, 0x0000, 0x1000);
		compose(ctx, "stage1", "scenes.stage1");
		Exception e = assertThrows(Exception.class, () -> CompositionChecks.verify(ctx));
		assertTrue(e.getMessage().contains("'scenes.lot' belongs to no composition"));
	}

	@Test
	@DisplayName("a composition naming an unknown scene is a build error")
	void unknownSceneIsRefused() throws Exception {
		BuildContext ctx = context();
		load(ctx, "scenes.stage1", "stage1.tiles", 26, 0x0000, 0x1000);
		compose(ctx, "stage1", "scenes.stage1", "scenes.typo");
		Exception e = assertThrows(Exception.class, () -> CompositionChecks.verify(ctx));
		assertTrue(e.getMessage().contains("scenes.typo"));
	}

	@Test
	@DisplayName("one file in two scenes is caught as sharing, never as colliding with itself")
	void sameFileTwiceIsNotACollision() throws Exception {
		BuildContext ctx = context();
		load(ctx, "scenes.stage1", "common.engine", 1, 0x6100, 0x1E07);
		load(ctx, "scenes.lot", "common.engine", 1, 0x6100, 0x1E07);
		compose(ctx, "stage1", "scenes.stage1", "scenes.lot");
		Exception e = assertThrows(Exception.class, () -> CompositionChecks.verify(ctx));
		assertTrue(e.getMessage().contains("is loaded by 2 of its scenes"));
		assertFalse(e.getMessage().contains("overlap on page"));
	}

	@Test
	@DisplayName("a file loaded by two scenes is refused : the convergence drops per scene")
	void aFileBelongsToOneScene() throws Exception {
		BuildContext ctx = context();
		load(ctx, "scenes.stage1", "lib.enemy", 26, 0x0000, 0x1000);
		load(ctx, "scenes.lot", "lib.enemy", 26, 0x0000, 0x1000);
		compose(ctx, "stage1", "scenes.stage1", "scenes.lot");
		Exception e = assertThrows(Exception.class, () -> CompositionChecks.verify(ctx));
		assertTrue(e.getMessage().contains("'lib.enemy' is loaded by 2 of its scenes"));
	}

	@Test
	@DisplayName("a configuration declaring nothing keeps its shared files : loader-ut arms its trap that way")
	void sharedFilesAreOnlyRefusedWhenStatesAreDeclared() throws Exception {
		BuildContext ctx = context();
		load(ctx, "scenes.main", "data.marker.bb", 6, 0x0000, 0x0100);
		load(ctx, "scenes.trap", "data.marker.bb", 6, 0x0000, 0x0100);
		CompositionChecks.verify(ctx);
	}

	@Test
	@DisplayName("two scenes of DIFFERENT states may share a file : the convergence drops then loads")
	void sharingAcrossStatesIsLegal() throws Exception {
		BuildContext ctx = context();
		load(ctx, "scenes.stage1", "lib.enemy", 26, 0x0000, 0x1000);
		load(ctx, "scenes.stage2", "lib.enemy", 26, 0x0000, 0x1000);
		compose(ctx, "stage1", "scenes.stage1");
		compose(ctx, "stage2", "scenes.stage2");
		CompositionChecks.verify(ctx);
	}

	@Test
	@DisplayName("declaring one name twice is refused : which one would the check use ?")
	void duplicateNameIsRefused() throws Exception {
		BuildContext ctx = context();
		compose(ctx, "stage1", "scenes.stage1");
		assertThrows(Exception.class, () -> compose(ctx, "stage1", "scenes.stage2"));
	}
}
