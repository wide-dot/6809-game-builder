package com.widedot.m6809.gamebuilder.plugin.pageset;

import static org.junit.jupiter.api.Assertions.*;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * The gap-driven cut (phase 5) : rigid files are placed first, collections
 * flow into what remains — one chunk per gap used, as big as its gap allows,
 * elements in declaration order. The gaps decide the cut, never a setting.
 */
class PageSetFlowTest {

	private static List<String[]> parts(int count) {
		List<String[]> parts = new ArrayList<String[]>();
		for (int i = 0; i < count; i++) {
			parts.add(new String[] { "path" + i, "el" + i });
		}
		return parts;
	}

	private static List<int[]> gaps(int[]... gaps) {
		return new ArrayList<int[]>(Arrays.asList(gaps));
	}

	@Test
	@DisplayName("the manual's example : two chunks, not five — the gaps decide")
	void gapsDecideTheCut() throws Exception {
		// a 9834 byte tail in page $18, pages $19 and $1A untouched ;
		// 17810 bytes of elements flow as 9826 + 7984, page $1A never used
		int[] sizes = new int[244];
		Arrays.fill(sizes, 73);
		sizes[243] = 71; // 243*73+71 = 17810
		PageSetPlugin.Flow flow = PageSetPlugin.flow("tiles", parts(244), sizes,
				gaps(new int[] { 0x18, 0x1734 + 610, 9834 },
					 new int[] { 0x19, 0x0000, 16384 },
					 new int[] { 0x1A, 0x0000, 16384 }), 256);
		assertEquals(2, flow.chunks.size());
		assertEquals(0x18, flow.chunkGaps.get(0)[0]);
		assertEquals(0x19, flow.chunkGaps.get(1)[0]);
		// the untouched page survives whole in the leftover
		boolean pageAfree = flow.leftover.stream().anyMatch(
				g -> g[0] == 0x1A && g[2] == 16384);
		assertTrue(pageAfree);
	}

	@Test
	@DisplayName("a gap under the threshold is left empty, not crumbled into")
	void thresholdLeavesSmallGapsEmpty() throws Exception {
		PageSetPlugin.Flow flow = PageSetPlugin.flow("s", parts(2), new int[] { 100, 100 },
				gaps(new int[] { 4, 0, 200 }, new int[] { 5, 0, 16384 }), 256);
		assertEquals(1, flow.chunks.size());
		assertEquals(5, flow.chunkGaps.get(0)[0]);
		assertTrue(flow.leftover.stream().anyMatch(g -> g[0] == 4 && g[2] == 200));
	}

	@Test
	@DisplayName("a consumed gap's unused tail stays available for the next set")
	void consumedTailStaysAvailable() throws Exception {
		// 300+300 fill gap one to 600 of 1000 ; 500 opens gap two
		PageSetPlugin.Flow flow = PageSetPlugin.flow("s", parts(3),
				new int[] { 300, 300, 500 },
				gaps(new int[] { 4, 0x1000, 1000 }, new int[] { 5, 0, 16384 }), 256);
		assertEquals(2, flow.chunks.size());
		assertTrue(flow.leftover.stream().anyMatch(
				g -> g[0] == 4 && g[1] == 0x1000 + 600 && g[2] == 400));
	}

	@Test
	@DisplayName("an offered gap too small for the element at hand survives whole")
	void skippedGapSurvivesWhole() throws Exception {
		PageSetPlugin.Flow flow = PageSetPlugin.flow("s", parts(1), new int[] { 800 },
				gaps(new int[] { 4, 0, 500 }, new int[] { 5, 0, 16384 }), 256);
		assertEquals(1, flow.chunks.size());
		assertEquals(5, flow.chunkGaps.get(0)[0]);
		assertTrue(flow.leftover.stream().anyMatch(g -> g[0] == 4 && g[2] == 500));
	}

	@Test
	@DisplayName("an element bigger than the roomiest gap is a named error")
	void oversizedElementIsANamedError() {
		Exception e = assertThrows(Exception.class, () -> PageSetPlugin.flow("s",
				parts(1), new int[] { 20000 }, gaps(new int[] { 4, 0, 16384 }), 256));
		assertTrue(e.getMessage().contains("el0"), e.getMessage());
	}

	@Test
	@DisplayName("a set that does not fit reports the shortfall")
	void overflowReportsTheShortfall() {
		Exception e = assertThrows(Exception.class, () -> PageSetPlugin.flow("s",
				parts(3), new int[] { 900, 900, 900 }, gaps(new int[] { 4, 0, 1000 }), 256));
		assertTrue(e.getMessage().contains("1800"), e.getMessage());
	}
}
