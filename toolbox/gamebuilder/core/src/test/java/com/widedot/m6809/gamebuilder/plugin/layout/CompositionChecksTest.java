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
		BuildContext ctx = new BuildContext(".", new Settings(new java.util.HashMap<String, String>()));
		// Every check reads places through the machine's windows : two files
		// reached through two different windows can be the same silicon, and a
		// context without a machine would compare nothing at all.
		ctx.machines.declare(to8());
		return ctx;
	}

	/** the target machine, reduced to what the checks read : its windows */
	private static com.widedot.m6809.gamebuilder.spi.globals.Machines.Machine to8() {
		java.util.List<com.widedot.m6809.gamebuilder.spi.globals.Machines.Window> windows =
				Arrays.asList(
				new com.widedot.m6809.gamebuilder.spi.globals.Machines.Window(
						"cart", 0x0000, 0x4000, null, "$E7E6", null, null, null),
				new com.widedot.m6809.gamebuilder.spi.globals.Machines.Window(
						"video", 0x4000, 0x2000, Integer.valueOf(0), null, null, null,
						Arrays.asList(
								new com.widedot.m6809.gamebuilder.spi.globals.Machines.Slice(0, 1),
								new com.widedot.m6809.gamebuilder.spi.globals.Machines.Slice(1, 0))),
				new com.widedot.m6809.gamebuilder.spi.globals.Machines.Window(
						"resident", 0x6000, 0x4000, Integer.valueOf(1), null, null, null, null),
				new com.widedot.m6809.gamebuilder.spi.globals.Machines.Window(
						"data", 0xA000, 0x4000, null, "$E7E5", null, null, null));
		return new com.widedot.m6809.gamebuilder.spi.globals.Machines.Machine(
				"to8", 32, 0x4000, "map.RAM_OVER_CART+", "map.const.asm", windows);
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
		assertTrue(e.getMessage().contains("overlap at page 26"), e.getMessage());
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
		assertFalse(e.getMessage().contains("overlap at page"));
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

	@Test
	@DisplayName("two windows, one silicon : $0000 in cartridge and $C000 in data collide")
	void collisionAcrossWindows() throws Exception {
		BuildContext ctx = context();
		// page 4 seen from the cartridge window starts at $0000 ; the same page
		// seen from the data window shows its first byte at $C000. Comparing
		// the declared addresses could never say these two are the same bytes.
		load(ctx, "scenes.a", "tiles", 4, 0x0000, 0x0400);
		load(ctx, "scenes.b", "table", 4, 0xC000, 0x0100);
		compose(ctx, "state", "scenes.a", "scenes.b");
		Exception e = assertThrows(Exception.class, () -> CompositionChecks.verify(ctx));
		assertTrue(e.getMessage().contains("tiles"), e.getMessage());
		assertTrue(e.getMessage().contains("table"), e.getMessage());
		assertTrue(e.getMessage().contains("page 4 +$0000"), e.getMessage());
	}

	@Test
	@DisplayName("a screen that runs past its page's end is compared in both its pieces")
	void wrappedPlaceIsComparedWhole() throws Exception {
		BuildContext ctx = context();
		// loaded at $7C00 in the resident window, 2019 bytes : page 1 +$3C00
		// to the end, then +$0000-$03E3 — the shape of r-type's nine screens
		load(ctx, "scenes.screen", "title.main", 1, 0x7C00, 2019);
		// and something sitting at the START of the same page, which the
		// screen's tail runs into
		load(ctx, "scenes.other", "globals", 1, 0x8100, 0x0100);
		compose(ctx, "state", "scenes.screen", "scenes.other");
		Exception e = assertThrows(Exception.class, () -> CompositionChecks.verify(ctx));
		assertTrue(e.getMessage().contains("title.main"), e.getMessage());
		assertTrue(e.getMessage().contains("globals"), e.getMessage());
	}
}
