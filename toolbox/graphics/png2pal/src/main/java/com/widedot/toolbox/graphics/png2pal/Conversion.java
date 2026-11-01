package com.widedot.toolbox.graphics.png2pal;

import java.awt.Color;
import java.util.List;

import com.widedot.m6809.util.color.LAB;

/**
 * Colours to the TO8 levels whose rendering is closest (CIEDE2000, the
 * profile's 16 levels a component), palette by palette.
 *
 * Two options, for a palette whose darks the TO8 cannot show : its first level
 * is already 97/255 (L* about 41), so every dark colour would meet there.
 * - lift : the lightness spread above that floor before the search, L* from..100
 *   to floor..100, a colour at black (L* at most black) kept ;
 * - darkest black : the darkest colour of each palette written black.
 *
 * Without them, the search is the one png2pal always made (util's LAB : Lab
 * rounded to whole numbers, a fast atan2). With either, it is v1 Another
 * World's (choice D), exactly : Lab as computed with its sRGB matrix, and
 * CIEDE2000 with the exact atan2 — the levels it chose, the same to the bit.
 */
final class Conversion {

	private final double[] lift;            // black, from, floor ; null : none
	private final boolean darkestBlack;
	private final boolean exact;            // v1's arithmetic
	private final LAB[] table = new LAB[4096];
	private final double[][] exactTable = new double[4096][];

	Conversion(int[] profile, double[] lift, boolean darkestBlack) {
		this.lift = lift;
		this.darkestBlack = darkestBlack;
		this.exact = lift != null || darkestBlack;
		for (int r = 0; r < 16; r++) {
			for (int g = 0; g < 16; g++) {
				for (int b = 0; b < 16; b++) {
					int i = r << 8 | g << 4 | b;
					if (exact) {
						exactTable[i] = lab(profile[r], profile[g], profile[b]);
					} else {
						table[i] = LAB.fromRGBr(profile[r], profile[g], profile[b], 1.0);
					}
				}
			}
		}
	}

	/** the levels (r, g, b) of each colour, the palettes being runs of {@code colors} colours */
	int[][] levels(List<Color> colours, int colors) {
		int[][] out = new int[colours.size()][];
		for (int p = 0; p < colours.size(); p += colors) {
			int end = Math.min(p + colors, colours.size());
			double dark = Double.POSITIVE_INFINITY;
			for (int i = p; i < end; i++) {
				dark = Math.min(dark, lab(colours.get(i))[0]);
			}
			for (int i = p; i < end; i++) {
				Color c = colours.get(i);
				out[i] = darkestBlack && lab(c)[0] == dark ? new int[] {0, 0, 0}
				       : exact ? nearestExact(c) : nearest(c);
			}
		}
		return out;
	}

	private int[] nearest(Color c) {
		LAB target = LAB.fromRGBr(c.getRed(), c.getGreen(), c.getBlue(), 1.0);
		int best = 0;
		double min = Double.POSITIVE_INFINITY;
		for (int j = 0; j < 4096; j++) {
			double d = LAB.ciede2000(target, table[j]);
			if (d < min) {
				min = d;
				best = j;
			}
		}
		return new int[] {best >> 8, (best >> 4) & 15, best & 15};
	}

	private int[] nearestExact(Color c) {
		double[] target = lab(c);
		if (lift != null && target[0] > lift[0]) {
			target = new double[] {lift[2] + Math.max(0.0, target[0] - lift[1]) * (100 - lift[2]) / (100 - lift[1]),
			                       target[1], target[2]};
		}
		int best = 0;
		double min = Double.POSITIVE_INFINITY;
		for (int j = 0; j < 4096; j++) {
			double d = ciede2000(target, exactTable[j]);
			if (d < min) {
				min = d;
				best = j;
			}
		}
		return new int[] {best >> 8, (best >> 4) & 15, best & 15};
	}

	private static double[] lab(Color c) {
		return lab(c.getRed(), c.getGreen(), c.getBlue());
	}

	/** sRGB (D65) to L*a*b*, v1's matrix */
	static double[] lab(int ri, int gi, int bi) {
		double r = lin(ri);
		double g = lin(gi);
		double b = lin(bi);
		double x = f((0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047);
		double y = f(0.2126 * r + 0.7152 * g + 0.0722 * b);
		double z = f((0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883);
		return new double[] {116 * y - 16, 500 * (x - y), 200 * (y - z)};
	}

	private static double lin(int c) {
		double v = c / 255.0;
		return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
	}

	private static double f(double t) {
		return t > 0.008856 ? Math.pow(t, 1.0 / 3) : 7.787 * t + 16.0 / 116;
	}

	/** CIEDE2000 (Sharma et al.), in degrees, the exact atan2 */
	static double ciede2000(double[] l1, double[] l2) {
		double c1 = Math.hypot(l1[1], l1[2]);
		double c2 = Math.hypot(l2[1], l2[2]);
		double cm7 = Math.pow((c1 + c2) / 2, 7);
		double g = 0.5 * (1 - Math.sqrt(cm7 / (cm7 + Math.pow(25, 7))));
		double a1p = (1 + g) * l1[1];
		double a2p = (1 + g) * l2[1];
		double c1p = Math.hypot(a1p, l1[2]);
		double c2p = Math.hypot(a2p, l2[2]);
		double h1p = mod360(Math.toDegrees(Math.atan2(l1[2], a1p)));
		double h2p = mod360(Math.toDegrees(Math.atan2(l2[2], a2p)));
		double dlp = l2[0] - l1[0];
		double dcp = c2p - c1p;
		double dh = h2p - h1p;
		if (c1p * c2p == 0) {
			dh = 0;
		} else if (dh > 180) {
			dh -= 360;
		} else if (dh < -180) {
			dh += 360;
		}
		double dhp = 2 * Math.sqrt(c1p * c2p) * Math.sin(Math.toRadians(dh / 2));
		double lpm = (l1[0] + l2[0]) / 2;
		double cpm = (c1p + c2p) / 2;
		double hpm;
		if (c1p * c2p == 0) {
			hpm = h1p + h2p;
		} else if (Math.abs(h1p - h2p) <= 180) {
			hpm = (h1p + h2p) / 2;
		} else {
			hpm = h1p + h2p < 360 ? (h1p + h2p + 360) / 2 : (h1p + h2p - 360) / 2;
		}
		double t = 1 - 0.17 * Math.cos(Math.toRadians(hpm - 30)) + 0.24 * Math.cos(Math.toRadians(2 * hpm))
		         + 0.32 * Math.cos(Math.toRadians(3 * hpm + 6)) - 0.20 * Math.cos(Math.toRadians(4 * hpm - 63));
		double sl = 1 + 0.015 * (lpm - 50) * (lpm - 50) / Math.sqrt(20 + (lpm - 50) * (lpm - 50));
		double sc = 1 + 0.045 * cpm;
		double sh = 1 + 0.015 * cpm * t;
		double cpm7 = Math.pow(cpm, 7);
		double rt = -2 * Math.sqrt(cpm7 / (cpm7 + Math.pow(25, 7)))
		          * Math.sin(Math.toRadians(60 * Math.exp(-Math.pow((hpm - 275) / 25, 2))));
		return Math.sqrt(Math.pow(dlp / sl, 2) + Math.pow(dcp / sc, 2) + Math.pow(dhp / sh, 2)
		               + rt * (dcp / sc) * (dhp / sh));
	}

	private static double mod360(double d) {
		double m = d % 360;
		return m < 0 ? m + 360 : m;
	}
}
