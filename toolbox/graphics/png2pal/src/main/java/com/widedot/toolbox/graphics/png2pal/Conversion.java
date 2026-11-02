package com.widedot.toolbox.graphics.png2pal;

import java.awt.Color;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

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
 * And one for a hue the search moves : zeros keep, a component at 0 in the
 * colour set to 0 in the levels found. Lifted, a dark saturated blue only
 * reaches its lightness with red and green it does not have (violets, mauve
 * greys) ; its zero components kept, it stays a blue, darker.
 *
 * And one for colours the search brings together : apart, from the darkest
 * colour of a palette up, a colour closer to one already placed than their own
 * distance (at most apart) searched again among the levels that keep those
 * distances, if one is at most apart further from its target. Lifted into the
 * TO8's light levels, close as they are there, two darks a few levels apart
 * may land on the same step of one component.
 *
 * And the choices no rule makes : set, a colour given its levels, wherever it is.
 *
 * Without them, the search is the one png2pal always made (util's LAB : Lab
 * rounded to whole numbers, a fast atan2). With either, it is v1 Another
 * World's (choice D), exactly : Lab as computed with its sRGB matrix, and
 * CIEDE2000 with the exact atan2 — the levels it chose, the same to the bit.
 */
final class Conversion {

	private final double[] lift;            // black, from, floor ; null : none
	private final boolean darkestBlack;
	private final boolean keepZeros;        // a component at 0 stays at 0
	private final double apart;             // the distance kept between two colours, 0 none
	private final Map<Integer, int[]> set;  // a colour's RGB -> its levels, after the rules
	private final boolean exact;            // v1's arithmetic
	private final LAB[] table = new LAB[4096];
	private final double[][] exactTable = new double[4096][];

	Conversion(int[] profile, double[] lift, boolean darkestBlack, boolean keepZeros, double apart,
	           Map<Integer, int[]> set) {
		this.set = set;
		this.lift = lift;
		this.darkestBlack = darkestBlack;
		this.keepZeros = keepZeros;
		this.apart = apart;
		this.exact = lift != null || darkestBlack || apart > 0;
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
				if (keepZeros) {
					out[i] = new int[] {c.getRed() == 0 ? 0 : out[i][0], c.getGreen() == 0 ? 0 : out[i][1],
					                    c.getBlue() == 0 ? 0 : out[i][2]};
				}
			}
			if (apart > 0) {
				apart(colours, p, end, out);
			}
			for (int i = p; i < end; i++) {
				int[] l = set.get(colours.get(i).getRGB() & 0xFFFFFF);
				if (l != null) {
					out[i] = l.clone();
				}
			}
		}
		return out;
	}

	/** the palette p..end-1 : its colours brought too close by the search set apart */
	private void apart(List<Color> colours, int p, int end, int[][] out) {
		List<Integer> order = new ArrayList<>();
		for (int i = p; i < end; i++) {
			order.add(i);
		}
		order.sort(Comparator.comparingDouble(i -> lab(colours.get(i))[0]));     // stable : the darkest first
		List<Integer> placed = new ArrayList<>();
		int[] ks = new int[end - p];
		double[] ds = new double[end - p];
		for (int j : order) {
			Color c = colours.get(j);
			int n = distances(colours, c, placed, ks, ds);
			boolean black = out[j][0] == 0 && out[j][1] == 0 && out[j][2] == 0;
			if (!black && !far(exactTable[index(out[j])], ks, ds, n, out)) {
				out[j] = searchApart(c, out[j], ks, ds, n, out);
			}
			placed.add(j);
		}
	}

	/** the colours placed other than c, in ks, and the distance c keeps from each, in ds : how many */
	private int distances(List<Color> colours, Color c, List<Integer> placed, int[] ks, double[] ds) {
		double[] lc = lab(c);
		int n = 0;
		for (int k : placed) {
			if (!colours.get(k).equals(c)) {
				ks[n] = k;
				ds[n++] = Math.min(ciede2000(lc, lab(colours.get(k))), apart);
			}
		}
		return n;
	}

	/** c's levels nearest its target that keep the distances, if at most apart further than now's */
	private int[] searchApart(Color c, int[] now, int[] ks, double[] ds, int n, int[][] out) {
		double[] target = target(c);
		double cur = ciede2000(target, exactTable[index(now)]);
		int best = -1;
		double min = Double.POSITIVE_INFINITY;
		for (int x = 0; x < 4096; x++) {
			if (zeroKept(c, x) && far(exactTable[x], ks, ds, n, out)) {
				double d = ciede2000(target, exactTable[x]);
				if (d < min) {
					min = d;
					best = x;
				}
			}
		}
		return best >= 0 && min <= cur + apart ? new int[] {best >> 8, (best >> 4) & 15, best & 15} : now;
	}

	/** levels x keep c's zero components at 0, or zeros are the search's */
	private boolean zeroKept(Color c, int x) {
		return !keepZeros || (c.getRed() != 0 || x >> 8 == 0) && (c.getGreen() != 0 || (x >> 4 & 15) == 0)
		                     && (c.getBlue() != 0 || (x & 15) == 0);
	}

	/** at least ds[i] from the levels of colour ks[i], each of the n */
	private boolean far(double[] l, int[] ks, double[] ds, int n, int[][] out) {
		for (int i = 0; i < n; i++) {
			if (ciede2000(l, exactTable[index(out[ks[i]])]) < ds[i]) {
				return false;
			}
		}
		return true;
	}

	private static int index(int[] levels) {
		return levels[0] << 8 | levels[1] << 4 | levels[2];
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

	/** the Lab the search aims at : the colour's, lifted */
	private double[] target(Color c) {
		double[] target = lab(c);
		if (lift != null && target[0] > lift[0]) {
			target = new double[] {lift[2] + Math.max(0.0, target[0] - lift[1]) * (100 - lift[2]) / (100 - lift[1]),
			                       target[1], target[2]};
		}
		return target;
	}

	private int[] nearestExact(Color c) {
		double[] target = target(c);
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
