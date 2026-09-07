package com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.configuration.NodeAttr;
import com.widedot.m6809.gamebuilder.spi.configuration.SourceMap;

public class Interleave {
	public int hardskip;
	public int softskip;
	public int softskew;
	public int[] hardMap;
	public int[] softMap;
	
	public int sectors;

	public Interleave(ImmutableNode node, SourceMap sources, int sectors) throws Exception {
		this(NodeAttr.getInteger(node, sources, "hardskip", 1),
		     NodeAttr.getInteger(node, sources, "softskip", 1),
		     NodeAttr.getInteger(node, sources, "softskew", 1),
		     sectors);
	}

	/** The same maps from bare values : a target overriding its storage's interleave. */
	public Interleave(int hardskip, int softskip, int softskew, int sectors) {
		this.hardskip = hardskip;
		this.softskip = softskip;
		this.softskew = softskew;
		this.sectors = sectors;
		// get interleaved map (as formatted on floppy disk)
		int[] uninterleavedMap = getUninterleavedMap(sectors);
		hardMap = getMap(hardskip, uninterleavedMap);
		softMap = getMap(softskip, hardMap);
	}

	/**
	 * Index in {@link #softMap} of the first logical sector of a track : the
	 * media rotates the soft map by {@code softskew} physical positions per
	 * track (FdUtil.interleave), and the loader has to start reading there.
	 */
	public int skewIndex(int track) {
		return getSoftIndex(softMap, hardMap[(track * softskew) % sectors]);
	}

	/** After how many tracks the skew pattern repeats. */
	public int skewPeriod() {
		int k = softskew % sectors;
		if (k == 0) return 1;
		return sectors / gcd(sectors, k);
	}

	private static int gcd(int a, int b) {
		while (b != 0) { int t = a % b; a = b; b = t; }
		return a;
	}
	
	public static int getSoftIndex(int[] map, int val) {
		int i = 0;
		for (i = 0; i < map.length; i++) {
			if (map[i] == val) break;
		}
		
		return i;
	}
	
	private int[] getUninterleavedMap(int sectors) {
		int[] defaultMap = new int[sectors];
		for (int i = 0 ; i < sectors; i++) {
			defaultMap[i] = i+1;
		}
		return defaultMap;
	}
	
	private int[] getMap(int skip, int[] imap) {
		
		// apply skip factor on sector list
		int[] omap = new int[imap.length];
		boolean[] bmap = new boolean[imap.length]; // mask for already copied values
		
		int j=0;
		for (int i = 0; i < imap.length; i++) {
			
			// skip already copied values
			while (bmap[j]) {
				j=(j+1)%imap.length;
			}
			
			omap[i] = imap[j]; // copy value
			bmap[j] = true;    // update mask
			
			// move byskip factor
			j=(j+skip)%imap.length;
		}
		
		return omap;
	}
	
}
