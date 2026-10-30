package com.widedot.m6809.gamebuilder.plugin.tilemap;

import static org.junit.jupiter.api.Assertions.*;

import java.awt.image.BufferedImage;
import java.awt.image.IndexColorModel;
import java.awt.image.WritableRaster;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * &lt;periodicband&gt; : the full lines' tables and the strip sheet, checked
 * against the picture at EVERY phase through a model of the runtime's reads
 * (engine/graphics/tilemap/periodicband/periodicband.asm) — the class
 * offsets, the pointer steps, the strips' places — and the generated source
 * against a reference.
 */
class PeriodicbandPluginTest {

	private static final int P = 48, W = 96;

	/**
	 * A test card, 96 x 10, period 48 : lines 0-2 full, 3-4 stems, 5-6 empty,
	 * 7 stems, 8-9 full. Every pixel of a full line differs from its
	 * neighbours, so a pair off by one pixel, a swapped plane or a wrong
	 * rotation reads a wrong byte.
	 */
	private static BufferedImage card() {
		byte[] r = new byte[17];
		IndexColorModel cm = new IndexColorModel(8, 17, r, r, r);
		BufferedImage im = new BufferedImage(W, 10, BufferedImage.TYPE_BYTE_INDEXED, cm);
		WritableRaster ras = im.getRaster();
		for (int y = 0; y < 10; y++) {
			for (int x = 0; x < W; x++) {
				int i = x % P;
				int v;
				if (y <= 2 || y >= 8) {
					v = 1 + (i * 7 + y * 3) % 16;          // full
				} else if (y == 5 || y == 6) {
					v = 0;                               // empty
				} else {
					v = (i % 5 == y % 5) ? 0 : 1 + (i + y) % 16; // stems
				}
				ras.setSample(x, y, 0, v);
			}
		}
		return im;
	}

	private static PeriodicbandPlugin.Band band(BufferedImage im) throws Exception {
		PeriodicbandPlugin.Band b = new PeriodicbandPlugin.Band(im.getRaster(), P, 8, 11, 144, "card");
		b.check();
		return b;
	}

	private static int pair(BufferedImage im, int i, int y) {
		int a = im.getRaster().getSample(Math.floorMod(i, P), y, 0);
		int b = im.getRaster().getSample(Math.floorMod(i + 1, P), y, 0);
		return ((a - 1) << 4) | (b - 1);
	}

	@Test
	@DisplayName("the lines fall in full, stems and empty ; the full ones in runs")
	void kinds() throws Exception {
		PeriodicbandPlugin.Band b = band(card());
		assertEquals(3, b.stemsTop);
		assertEquals(7, b.stemsBottom);
		assertEquals(5, b.fullCount());
		assertEquals(2, b.runs().size());
		assertArrayEquals(new int[] { 0, 3 }, b.runs().get(0));
		assertArrayEquals(new int[] { 8, 2 }, b.runs().get(1));
	}

	@Test
	@DisplayName("the writer's reads give the window's bytes at every phase, both planes, line after line")
	void writerEveryPhase() throws Exception {
		BufferedImage im = card();
		PeriodicbandPlugin.Band b = band(im);
		int bytes = P / 4, table = 2 * bytes, parity = 2 * table, line = 2 * parity;
		// the tables of the first run, as the runtime sees them : one stream
		int[] stream = new int[3 * line];
		for (int l = 0; l < 3; l++) {
			System.arraycopy(b.tables(l), 0, stream, l * line, line);
		}
		for (int p = 0; p < P; p++) {
			// periodicband.draw's class, the same arithmetic
			int e = p & 1, s = p >> 1, t = s >> 1;
			boolean swap = (s & 1) != 0;
			int u = e * parity + (swap ? t + 1 : table + t);
			int d1 = swap ? table - 1 - bytes : -(table + bytes);
			int d2 = swap ? line - table - bytes + 1 : line + table - bytes;
			for (int l = 0; l < 3; l++) {
				for (int plane = 0; plane < 2; plane++) {   // $A000 zone, then $C000
					for (int c = 0; c < 36; c++) {
						int got = stream[u + c % bytes];
						// window pixel x shows picture pixel x + p ; the $C000
						// plane holds the pairs at 4c, the $A000 one at 4c + 2
						int want = pair(im, 4 * c + (plane == 0 ? 2 : 0) + p, l);
						assertEquals(want, got, "phase " + p + " line " + l + " plane " + plane + " byte " + c);
					}
					u += bytes;
					u += plane == 0 ? d1 : d2;
				}
			}
		}
	}

	@Test
	@DisplayName("the strips, placed as the runtime places them, show the picture at every phase")
	void stripsEveryPhase() throws Exception {
		BufferedImage im = card();
		PeriodicbandPlugin.Band b = band(im);
		int perParity = P / PeriodicbandPlugin.STRIP;
		for (int p = 0; p < P; p++) {
			int e = p & 1, q = p - e;
			int k0 = q / 16, x0 = -(q % 16);
			int n = 144 / 16 + (q % 16 != 0 ? 1 : 0);
			for (int y = b.stemsTop; y <= b.stemsBottom; y++) {
				for (int x = 0; x < 144; x++) {
					int i = (x - x0) / 16;                   // the strip over x
					assertTrue(i < n, "phase " + p + " : no strip over x " + x);
					int cell = e * perParity + (k0 + i) % perParity;
					int got = b.sheetPixel(cell * 16 + (x - x0) % 16, y - b.stemsTop);
					int want = b.full[y] ? 0 : im.getRaster().getSample((x + p) % P, y, 0);
					assertEquals(want, got, "phase " + p + " line " + y + " x " + x);
				}
			}
			// the spill stays inside the 8 px margins of the screen
			assertTrue(8 + x0 >= -8 && 8 + x0 + 16 * n <= 168, "phase " + p);
		}
	}

	@Test
	@DisplayName("the generated source : geometry, runs, tables and the strip table, to the byte")
	void source() throws Exception {
		BufferedImage im = card();
		String src = band(im).source("card.png", "host", "code");
		String nl = System.lineSeparator();
		assertTrue(src.startsWith("* Generated by periodicband from card.png" + nl
				+ "* period 48 px, window x 8 width 144, picture lines at screen lines 11-20" + nl
				+ "periodicband.PERIOD      equ 48" + nl
				+ "periodicband.WIDTH       equ 144" + nl
				+ "periodicband.X           equ 8" + nl
				+ "periodicband.RUNS        equ 2" + nl
				+ "periodicband.STEMS       equ 1" + nl
				+ "periodicband.STEMS.Y     equ 14" + nl
				+ "periodicband.STEMS.H     equ 5" + nl
				+ "periodicband.STRIP.ENTRIES equ 12" + nl
				+ nl
				+ " SECTION code" + nl), src);
		assertTrue(src.contains("periodicband.runs" + nl
				+ "        fdb   440              ; line 11" + nl
				+ "        fcb   3" + nl
				+ "        fdb   periodicband.lines+0" + nl
				+ "        fdb   760              ; line 19" + nl
				+ "        fcb   2" + nl
				+ "        fdb   periodicband.lines+288" + nl), src);
		// line 0, parity 0, even pairs : (0,1) (4,5) ... of the picture
		StringBuilder first = new StringBuilder("* line 11" + nl + "        fcb   ");
		for (int m = 0; m < 12; m++) {
			first.append(m == 0 ? "" : ",").append(String.format("$%02X", pair(im, 4 * m, 0)));
		}
		assertTrue(src.contains(first.toString() + nl), src);
		assertTrue(src.contains("periodicband.strips" + nl
				+ "        fdb   adr_host_0_ND0" + nl
				+ "        fdb   adr_host_1_ND0" + nl
				+ "        fdb   adr_host_2_ND0" + nl
				+ "        fdb   adr_host_0_ND0" + nl), src);
		assertTrue(src.endsWith("        fdb   adr_host_5_ND0" + nl + " ENDSECTION" + nl), src);
	}

	@Test
	@DisplayName("a picture that breaks its period, or a period that is not a multiple of 16, is a named error")
	void errors() throws Exception {
		BufferedImage im = card();
		im.getRaster().setSample(60, 1, 0, 3);
		assertNotEquals(im.getRaster().getSample(12, 1, 0), 3);
		Exception broken = assertThrows(Exception.class, () -> band(im));
		assertTrue(broken.getMessage().contains("breaks the period"), broken.getMessage());
		PeriodicbandPlugin.Band odd = new PeriodicbandPlugin.Band(card().getRaster(), 24, 8, 11, 144, "card");
		Exception period = assertThrows(Exception.class, odd::check);
		assertTrue(period.getMessage().contains("not a multiple of 16"), period.getMessage());
	}
}
