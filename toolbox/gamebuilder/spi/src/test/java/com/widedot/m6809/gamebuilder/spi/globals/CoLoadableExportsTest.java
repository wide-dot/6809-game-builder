package com.widedot.m6809.gamebuilder.spi.globals;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * Export uniqueness per co-loadable set, and the interface promise of a
 * region : the builder half of swappable stages. Two direntries the scenes
 * load at the same exact destination are mutually exclusive at run time
 * (implicit unload by destination), so they may share export names ; a
 * region declared interface="true" further requires its alternatives to
 * emit the same export list.
 */
class CoLoadableExportsTest {

	private LinkSymbols withPlacements(StaticLink placements) {
		LinkSymbols symbols = new LinkSymbols();
		symbols.placements = placements;
		return symbols;
	}

	@Test
	@DisplayName("direntries at the same destination may share export names")
	void alternativesShareNames() throws Exception {
		StaticLink placements = new StaticLink();
		placements.place("stage1", 4, 0xA000, "scene.one");
		placements.place("stage2", 4, 0xA000, "scene.two");
		LinkSymbols symbols = withPlacements(placements);

		symbols.beginUnit("stage1");
		int first = symbols.export("Obj_Index_Page", "main.o");
		symbols.beginUnit("stage2");
		int second = symbols.export("Obj_Index_Page", "main.o");

		// same name -> same link id, whoever is loaded resolves it
		assertEquals(first, second);
	}

	@Test
	@DisplayName("direntries at different destinations keep global uniqueness")
	void coexistingDirentriesRejected() throws Exception {
		StaticLink placements = new StaticLink();
		placements.place("stage1", 4, 0xA000, "scene.one");
		placements.place("engine", 2, 0x6100, "scene.one");
		LinkSymbols symbols = withPlacements(placements);

		symbols.beginUnit("stage1");
		symbols.export("Obj_Index_Page", "main.o");
		symbols.beginUnit("engine");
		Exception e = assertThrows(Exception.class,
				() -> symbols.export("Obj_Index_Page", "engine.o"));
		assertTrue(e.getMessage().contains("stage1"), e.getMessage());
	}

	@Test
	@DisplayName("a direntry no scene places keeps global uniqueness")
	void unplacedDirentryRejected() throws Exception {
		StaticLink placements = new StaticLink();
		placements.place("stage1", 4, 0xA000, "scene.one");
		LinkSymbols symbols = withPlacements(placements);

		symbols.beginUnit("stage1");
		symbols.export("Obj_Index_Page", "main.o");
		symbols.beginUnit("loose");
		assertThrows(Exception.class, () -> symbols.export("Obj_Index_Page", "loose.o"));
	}

	@Test
	@DisplayName("a direntry loaded at two destinations is no alternative to anyone")
	void conflictedDirentryRejected() throws Exception {
		StaticLink placements = new StaticLink();
		placements.place("stage1", 4, 0xA000, "scene.one");
		placements.place("stage2", 4, 0xA000, "scene.two");
		placements.place("stage2", 5, 0xC000, "scene.aside");
		LinkSymbols symbols = withPlacements(placements);

		symbols.beginUnit("stage1");
		symbols.export("Obj_Index_Page", "main.o");
		symbols.beginUnit("stage2");
		assertThrows(Exception.class, () -> symbols.export("Obj_Index_Page", "main.o"));
	}

	@Test
	@DisplayName("two files of the same direntry cannot export the same name")
	void sameUnitStillRejected() throws Exception {
		StaticLink placements = new StaticLink();
		placements.place("stage1", 4, 0xA000, "scene.one");
		LinkSymbols symbols = withPlacements(placements);

		symbols.beginUnit("stage1");
		symbols.export("Obj_Index_Page", "main.o");
		assertThrows(Exception.class, () -> symbols.export("Obj_Index_Page", "tables.o"));
	}

	@Test
	@DisplayName("an interface region accepts alternatives with identical export lists")
	void interfaceAcceptsIdenticalLists() throws Exception {
		StaticLink placements = new StaticLink();
		placements.declareInterfaceRegion("stage", 4, 0xA000);
		placements.place("stage1", 4, 0xA000, "scene.one");
		placements.place("stage2", 4, 0xA000, "scene.two");
		LinkSymbols symbols = withPlacements(placements);

		symbols.beginUnit("stage1");
		symbols.export("Obj_Index_Page", "main.o");
		symbols.export("wave.data", "main.o");
		symbols.beginUnit("stage2");
		symbols.export("Obj_Index_Page", "main.o");
		symbols.export("wave.data", "main.o");

		placements.checkInterfaces(symbols.unitExports);
	}

	@Test
	@DisplayName("an interface region rejects alternatives with differing export lists")
	void interfaceRejectsDifferingLists() throws Exception {
		StaticLink placements = new StaticLink();
		placements.declareInterfaceRegion("stage", 4, 0xA000);
		placements.place("stage1", 4, 0xA000, "scene.one");
		placements.place("stage2", 4, 0xA000, "scene.two");
		LinkSymbols symbols = withPlacements(placements);

		symbols.beginUnit("stage1");
		symbols.export("Obj_Index_Page", "main.o");
		symbols.export("wave.data", "main.o");
		symbols.beginUnit("stage2");
		symbols.export("Obj_Index_Page", "main.o");

		Exception e = assertThrows(Exception.class,
				() -> placements.checkInterfaces(symbols.unitExports));
		assertTrue(e.getMessage().contains("wave.data"), e.getMessage());
	}

	@Test
	@DisplayName("the interface promise is checked on what the link data emits, post-prune")
	void interfaceComparesEmittedListsOnly() throws Exception {
		StaticLink placements = new StaticLink();
		placements.declareInterfaceRegion("stage", 4, 0xA000);
		placements.place("stage1", 4, 0xA000, "scene.one");
		placements.place("stage2", 4, 0xA000, "scene.two");
		LinkSymbols symbols = withPlacements(placements);

		// only wave.data is imported : the stage2-only export is pruned from
		// the link data, so the run-time faces are identical after all
		symbols.preseedImports(new java.util.HashSet<String>(java.util.Arrays.asList("wave.data")));
		symbols.beginUnit("stage1");
		symbols.export("wave.data", "main.o");
		symbols.beginUnit("stage2");
		symbols.export("wave.data", "main.o");
		symbols.export("stage2.debug.hook", "main.o");

		placements.checkInterfaces(symbols.unitExports);
	}

	@Test
	@DisplayName("an alternative also loaded outside its interface region is rejected")
	void interfaceMemberLoadedElsewhereRejected() throws Exception {
		StaticLink placements = new StaticLink();
		placements.declareInterfaceRegion("stage", 4, 0xA000);
		placements.place("stage1", 4, 0xA000, "scene.one");
		placements.place("stage1", 5, 0xC000, "scene.aside");
		LinkSymbols symbols = withPlacements(placements);

		Exception e = assertThrows(Exception.class,
				() -> placements.checkInterfaces(symbols.unitExports));
		assertTrue(e.getMessage().contains("stage1"), e.getMessage());
	}
}
