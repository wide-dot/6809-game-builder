package com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

public class Interleave {
	public int hardskip;
	public int softskip;
	public int softskew;
	public int[] hardMap;
	public int[] softMap;
	
	public Interleave(HierarchicalConfiguration<ImmutableNode> node, int sectors) throws Exception {
		hardskip = node.getInteger("[@hardskip]", 1);
		softskip = node.getInteger("[@softskip]", 1);
		softskew = node.getInteger("[@softskew]", 1);
		
		// get interleaved map (as formatted on floppy disk)
		int[] uninterleavedMap = getUninterleavedMap(sectors);
		hardMap = getMap(hardskip, uninterleavedMap);
		softMap = getMap(softskip, hardMap);
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
