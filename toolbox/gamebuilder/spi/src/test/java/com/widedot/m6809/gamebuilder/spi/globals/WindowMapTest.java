package com.widedot.m6809.gamebuilder.spi.globals;

import static org.junit.jupiter.api.Assertions.*;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * The TO8 window arithmetic, against the table MEASURED on the machine and
 * confirmed in the emulator's own pager : the cartridge window is straight,
 * the resident and data windows show a page from its middle, and the video
 * window numbers the two halves backwards.
 *
 * These are not invented cases : every number below appears in r-type's
 * configuration or in its memory, and the wrap case is its nine screens.
 */
class WindowMapTest {

	private static Machines.Machine to8() {
		List<Machines.Window> windows = Arrays.asList(
				new Machines.Window("cart", 0x0000, 0x4000, null, "$E7E6",
						"map.RAM_OVER_CART", "map.const.asm", null),
				new Machines.Window("video", 0x4000, 0x2000, Integer.valueOf(0), null, null, null,
						Arrays.asList(new Machines.Slice(0, 1), new Machines.Slice(1, 0))),
				new Machines.Window("resident", 0x6000, 0x4000, Integer.valueOf(1), null, null,
						null, null),
				new Machines.Window("data", 0xA000, 0x4000, null, "$E7E5", null, null, null));
		return new Machines.Machine("to8", 32, 0x4000, "map.RAM_OVER_CART+", "map.const.asm",
				windows);
	}

	private static WindowMap map() {
		return to8().windows();
	}

	private static Machines.Window win(String name) throws Exception {
		for (Machines.Window w : to8().windows) {
			if (w.name.equals(name)) {
				return w;
			}
		}
		throw new Exception(name);
	}

	@Test
	@DisplayName("an address names one window and one only")
	void windowOfAddress() throws Exception {
		assertEquals("cart", map().of(0x2000).name);
		assertEquals("video", map().of(0x4000).name);
		assertEquals("resident", map().of(0x7C00).name);
		assertEquals("data", map().of(0xC000).name);
	}

	@Test
	@DisplayName("an address in no window is refused, listing the windows")
	void addressOutside() {
		Exception e = assertThrows(Exception.class, () -> map().of(0xE000));
		assertTrue(e.getMessage().contains("no window"), e.getMessage());
		assertTrue(e.getMessage().contains("resident $6000-$9FFF"), e.getMessage());
	}

	@Test
	@DisplayName("the cartridge window is straight : position = address")
	void cartIsStraight() throws Exception {
		assertEquals(0x0000, map().positionOf(win("cart"), 0x0000, null));
		assertEquals(0x2000, map().positionOf(win("cart"), 0x2000, null));
		assertEquals(0x3FFF, map().positionOf(win("cart"), 0x3FFF, null));
	}

	@Test
	@DisplayName("the resident window shows the page from its middle (measured)")
	void residentFolds() throws Exception {
		assertEquals(0x2000, map().positionOf(win("resident"), 0x6000, null));
		assertEquals(0x3C00, map().positionOf(win("resident"), 0x7C00, null));
		assertEquals(0x0000, map().positionOf(win("resident"), 0x8000, null));
		assertEquals(0x1EF0, map().positionOf(win("resident"), 0x9EF0, null));
	}

	@Test
	@DisplayName("the data window shows it the same way : $C000 is the page's first byte")
	void dataFolds() throws Exception {
		assertEquals(0x2000, map().positionOf(win("data"), 0xA000, null));
		assertEquals(0x0000, map().positionOf(win("data"), 0xC000, null));
	}

	@Test
	@DisplayName("the video window numbers its halves backwards : slice 0 is bit 1")
	void videoSlicesAreInverted() throws Exception {
		assertEquals(0x0000, map().positionOf(win("video"), 0x4000, Integer.valueOf(0)));
		assertEquals(0x2000, map().positionOf(win("video"), 0x4000, Integer.valueOf(1)));
		assertEquals(1, map().selectorOf(win("video"), null, Integer.valueOf(0)));
		assertEquals(0, map().selectorOf(win("video"), null, Integer.valueOf(1)));
	}

	@Test
	@DisplayName("r-type's bullet table : video slice 1, $5D40, lands at +$3D40")
	void bulletsLandWhereTheAsmSaid() throws Exception {
		assertEquals(0x3D40, map().positionOf(win("video"), 0x5D40, Integer.valueOf(1)));
	}

	@Test
	@DisplayName("address and position are inverses of each other")
	void roundTrip() throws Exception {
		for (int cpu = 0x6000; cpu < 0xA000; cpu += 0x100) {
			assertEquals(cpu, map().cpuOf(win("resident"), map().positionOf(win("resident"), cpu, null)));
		}
		assertEquals(0x87F2, map().cpuOf(win("resident"), 0x07F2));
	}

	@Test
	@DisplayName("a place may run past the page's end and continue at its start")
	void screensWrapThePage() throws Exception {
		// title.main : loaded at $7C00 in the resident window, 2019 bytes
		List<int[]> f = map().footprint(win("resident"), null, 0x7C00, 2019, null);
		assertEquals(2, f.size());
		assertArrayEquals(new int[] { 0x4000 + 0x3C00, 0x4000 + 0x4000 }, f.get(0));
		assertArrayEquals(new int[] { 0x4000, 0x4000 + 0x03E3 }, f.get(1));
	}

	@Test
	@DisplayName("a place that stays inside its page has one footprint")
	void shortPlaceDoesNotWrap() throws Exception {
		List<int[]> f = map().footprint(win("cart"), Integer.valueOf(0x17), 0x0000, 0x4000, null);
		assertEquals(1, f.size());
		assertArrayEquals(new int[] { 0x17 * 0x4000, 0x18 * 0x4000 }, f.get(0));
	}

	@Test
	@DisplayName("running past the WINDOW is refused — those bytes are another space")
	void placeMustStayInItsWindow() {
		Exception e = assertThrows(Exception.class,
				() -> map().checkFits(win("cart"), 0x3000, 0x2000));
		assertTrue(e.getMessage().contains("runs past the 'cart' window"), e.getMessage());
		assertTrue(e.getMessage().contains("$4000"), e.getMessage());
	}

	@Test
	@DisplayName("a window on a fixed page cannot be told another one")
	void fixedPageWindowRefusesAPage() {
		Exception e = assertThrows(Exception.class,
				() -> map().selectorOf(win("video"), Integer.valueOf(1), Integer.valueOf(0)));
		assertTrue(e.getMessage().contains("window on page 0"), e.getMessage());
	}

	@Test
	@DisplayName("a paging window needs a page, and refuses one the machine has not")
	void pagingWindowNeedsAPage() {
		Exception missing = assertThrows(Exception.class,
				() -> map().selectorOf(win("cart"), null, null));
		assertTrue(missing.getMessage().contains("a page is needed"), missing.getMessage());
		Exception tooFar = assertThrows(Exception.class,
				() -> map().selectorOf(win("cart"), Integer.valueOf(40), null));
		assertTrue(tooFar.getMessage().contains("32 pages"), tooFar.getMessage());
	}

	@Test
	@DisplayName("a slice is required where the window is smaller than a page, and refused elsewhere")
	void sliceIsRequiredOnlyWhereItMeansSomething() {
		Exception missing = assertThrows(Exception.class,
				() -> map().positionOf(win("video"), 0x4000, null));
		assertTrue(missing.getMessage().contains("which slice"), missing.getMessage());
		Exception extra = assertThrows(Exception.class,
				() -> map().positionOf(win("cart"), 0x0000, Integer.valueOf(0)));
		assertTrue(extra.getMessage().contains("takes no slice"), extra.getMessage());
	}

	@Test
	@DisplayName("a machine with no windows says so rather than letting a null travel")
	void noWindowsDeclared() {
		Machines.Machine bare = new Machines.Machine("bare", 8, 0x4000, "x", "y",
				Collections.<Machines.Window>emptyList());
		Exception e = assertThrows(Exception.class, () -> bare.windows().of(0x1000));
		assertTrue(e.getMessage().contains("no window"), e.getMessage());
	}
}
