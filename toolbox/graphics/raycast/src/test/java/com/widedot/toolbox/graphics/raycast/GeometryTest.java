package com.widedot.toolbox.graphics.raycast;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/** the view's geometry : heights, centring, screen addresses */
class GeometryTest {

	@Test
	void aWallIsCentred() {
		for (Geometry g : ScalerTest.VIEWS) {
			for (int h : g.heights()) {
				assertEquals(0, h % 2, "an odd height cannot be centred : " + h);
				assertEquals(0, h % g.lines, "a height is whole samples : " + h);
				if (h <= g.rows) {
					assertEquals(g.rows, 2 * g.topRow(h) + h, "as many rows over the wall as under it : " + h);
				}
			}
			assertEquals(g.maxHeight, (int) g.heights().get(g.heights().size() - 1));
			assertTrue(g.indexMax() <= 255, "a height's index is a byte");
		}
	}

	@Test
	void columnsOfTheScreen() {
		Geometry whole = Views.whole();
		assertEquals(0xC000, whole.columnAddress(0));
		assertEquals(0xA000, whole.columnAddress(1));
		assertEquals(0xC000 + 39, whole.columnAddress(78));
		assertEquals(0xA000 + 39, whole.columnAddress(79));
		Geometry small = Views.small();
		assertEquals(0xC000 + 36 * 40 + 4, small.columnAddress(0));
		assertEquals(0xA000 + 36 * 40 + 4, small.columnAddress(1));
		assertEquals(0xA000 + 36 * 40 + 4 + 31, small.columnAddress(63));
	}

	@Test
	void theWholeScreensScalers() {
		Geometry g = Views.whole();
		assertEquals(130, g.heights().size());
		int bytes = 0;
		ScalerGen gen = new ScalerGen(g);
		for (int h : g.heights()) {
			bytes += gen.routine(h).size;
		}
		assertEquals(64472, bytes);
	}
}
