package com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

public class Segment {

	public int faces;
	public int tracks;
	public int sectors;
	public int sectorSize;
	
	public Segment (HierarchicalConfiguration<ImmutableNode> node) throws Exception {
		
		faces = node.getInteger("[@faces]", -1);
		if (faces == -1) {
			throw new Exception("faces is missing for segment");
		}
		
		tracks = node.getInteger("[@tracks]", -1);
		if (tracks == -1) {
			throw new Exception("tracks is missing for segment");
		}
		
		sectors = node.getInteger("[@sectors]", -1);
		if (sectors == -1) {
			throw new Exception("sectors is missing for segment");
		}
	    
		sectorSize = node.getInteger("[@sectorSize]", -1);
		if (sectorSize == -1) {
			throw new Exception("sectorSize is missing for segment");
		}	
	}
}
