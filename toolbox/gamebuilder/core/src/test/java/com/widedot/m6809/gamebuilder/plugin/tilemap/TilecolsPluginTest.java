package com.widedot.m6809.gamebuilder.plugin.tilemap;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * The column tables of &lt;tilecols&gt; : one word per column, then each
 * column's full cells (page, address, video offset) and a 0 ; with a
 * `behind` mask, the masked cells move to a second table, label.behind.
 */
class TilecolsPluginTest {

	private static final String NL = System.lineSeparator();

	// 2 columns of 3 rows : column 0 = tiles 1, -, 2 ; column 1 = -, 3, -
	private static final int[] IDS = { 1, 0, 2, 0, 3, 0 };

	private static String cell(int id, int offset) {
		return "        fcb   P+adr_t_" + id + "_ND0$PAGE" + NL
				+ "        fdb   adr_t_" + id + "_ND0" + NL
				+ "        fdb   " + offset + NL;
	}

	private static String head(String label) {
		return label + " EXPORT" + NL + " SECTION map" + NL + label + NL
				+ "        fdb   " + label + ".c0" + NL
				+ "        fdb   " + label + ".c1" + NL;
	}

	private static String table(String label, boolean[] dense, byte[] behind, boolean back,
			int[] stats) throws Exception {
		StringBuilder out = new StringBuilder();
		TilecolsPlugin.columns(out, label, IDS, 2, 3, dense, behind, back, "t", "ND0",
				"P+", "ANY", "tilemap.null", 480, "map", stats);
		return out.toString();
	}

	@Test
	@DisplayName("without a mask : the full cells only, the 0 ending each column")
	void sparse() throws Exception {
		int[] stats = new int[3];
		String got = table("map", new boolean[2], null, false, stats);
		String want = head("map")
				+ "map.c0" + NL + cell(1, 0) + cell(2, 960) + "        fcb   0" + NL
				+ "map.c1" + NL + cell(3, 480) + "        fcb   0" + NL
				+ " ENDSECTION" + NL;
		assertEquals(want, got);
		assertArrayEquals(new int[] { 3, 0, 2 * 2 + 3 * 5 + 2 }, stats);
	}

	@Test
	@DisplayName("a mask splits the cells : the masked ones in label.behind, the others in label")
	void behind() throws Exception {
		byte[] mask = { 0, 0, 1, 0, 1, 0 };   // tile 2 (col 0 row 2) and tile 3 behind
		int[] stats = new int[3];
		String front = table("map", new boolean[2], mask, false, stats);
		String back = table("map.behind", new boolean[2], mask, true, stats);
		assertEquals(head("map")
				+ "map.c0" + NL + cell(1, 0) + "        fcb   0" + NL
				+ "map.c1" + NL + "        fcb   0" + NL
				+ " ENDSECTION" + NL, front);
		assertEquals(head("map.behind")
				+ "map.behind.c0" + NL + cell(2, 960) + "        fcb   0" + NL
				+ "map.behind.c1" + NL + cell(3, 480) + "        fcb   0" + NL
				+ " ENDSECTION" + NL, back);
		assertEquals(3, stats[0]);
	}

	@Test
	@DisplayName("a mask on an empty cell is ignored ; a dense column keeps its rows in label")
	void denseFront() throws Exception {
		byte[] mask = { 0, 1, 0, 1, 0, 1 };   // only empty cells masked
		int[] stats = new int[3];
		String front = table("map", new boolean[] { false, true }, mask, false, stats);
		assertTrue(front.contains("map.c1" + NL
				+ "        fcb   ANY" + NL + "        fdb   tilemap.null" + NL + "        fdb   0" + NL
				+ cell(3, 480)
				+ "        fcb   ANY" + NL + "        fdb   tilemap.null" + NL + "        fdb   960" + NL
				+ "        fcb   0" + NL));
		String back = table("map.behind", new boolean[] { false, true }, mask, true, stats);
		assertTrue(back.contains("map.behind.c1" + NL + "        fcb   0" + NL));
	}

	@Test
	@DisplayName("a dense column may not hold a cell behind the sprites")
	void denseBehindRefused() {
		byte[] mask = { 0, 0, 0, 0, 1, 0 };
		Exception e = assertThrows(Exception.class,
				() -> table("map", new boolean[] { false, true }, mask, false, new int[3]));
		assertTrue(e.getMessage().contains("column 1 is dense"));
	}
}
