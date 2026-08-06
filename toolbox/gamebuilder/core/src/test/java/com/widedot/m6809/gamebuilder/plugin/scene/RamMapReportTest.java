package com.widedot.m6809.gamebuilder.plugin.scene;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

import com.widedot.m6809.gamebuilder.spi.globals.RamMap;
import com.widedot.m6809.gamebuilder.spi.globals.Regions;

/**
 * The map is read before choosing where a new object goes, so what it must get
 * right is the room left over : the gaps between declarations, and how much of
 * each budget the content really uses.
 */
public class RamMapReportTest {

	private static Regions layout() throws Exception {
		Regions regions = new Regions();
		regions.put(new Regions.Region("common", 1, 0x6100, 0x2200, 1));
		regions.put(new Regions.Region("stage", 1, 0x8300, 0x0D00, 1));
		regions.put(new Regions.Region("tiles", 6, 0x0000, 0x4000, 2));
		regions.reserve(new Regions.Reserved("objects.pool", 1, 0x90B0, 0x0750));
		return regions;
	}

	@Test
	void aGapBetweenDeclarationsIsMeasured() throws Exception {
		RamMap map = new RamMap();
		map.record("boot", new RamMap.Load("engine", "common", 1, 0x6100, 7687));

		String report = RamMapReport.render("fd", map, layout());

		// stage ends at $9000, the pool starts at $90B0 : 176 bytes nobody claims
		assertTrue(report.contains("$9000-$90AF  free"), report);
		assertTrue(report.contains("176"), report);
		assertTrue(report.contains("$90B0-$97FF  reserved  objects.pool"), report);
	}

	@Test
	void aBudgetIsShownAgainstWhatIsReallyLoaded() throws Exception {
		RamMap map = new RamMap();
		map.record("boot", new RamMap.Load("engine", "common", 1, 0x6100, 7687));

		String report = RamMapReport.render("fd", map, layout());

		assertTrue(report.matches("(?s).*region\\s+common\\s+8704\\s+engine\\s+7687\\s+88%.*"), report);
	}

	/**
	 * A region this scene does not load is not free : an earlier scene put
	 * something there, and the builder does not know sequences. Reporting it
	 * as room would be an invitation to place an object on top of the engine.
	 */
	@Test
	void aRegionTheSceneLeavesAloneIsNotReportedAsFree() throws Exception {
		RamMap map = new RamMap();
		map.record("stage1", new RamMap.Load("stage1", "stage", 1, 0x8300, 1501));

		String report = RamMapReport.render("fd", map, layout());

		assertTrue(report.matches("(?s).*common\\s+8704\\s+\\(not loaded by this scene\\).*"), report);
		assertFalse(report.contains("$6100-$82FF  free"), report);
	}

	/**
	 * A pageset member lands on one page of its region. Summing the set on
	 * every page of the region would report each of them several times full —
	 * measured 413 % on a five page tileset before this was keyed by page.
	 */
	@Test
	void aMultiPageRegionCountsEachPageOnItsOwn() throws Exception {
		RamMap map = new RamMap();
		map.record("boot", new RamMap.Load("tiles.0", "tiles", 6, 0x0000, 16163));
		map.record("boot", new RamMap.Load("tiles.1", "tiles", 7, 0x0000, 7323));

		String report = RamMapReport.render("fd", map, layout());

		assertTrue(report.matches("(?s).*tiles\\.0\\s+16163\\s+98%.*"), report);
		assertTrue(report.matches("(?s).*tiles\\.1\\s+7323\\s+44%.*"), report);

		java.util.regex.Matcher fill = java.util.regex.Pattern.compile("(\\d+)%").matcher(report);
		while (fill.find()) {
			assertTrue(Integer.parseInt(fill.group(1)) <= 100,
					"a page cannot be more than full : " + fill.group() + "\n" + report);
		}
	}
}
