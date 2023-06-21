package com.widedot.m6809.gamebuilder.configuration;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

public class Fat {

	public String name;
	public Integer sectorPerBlock;
	public Integer nBlocks;
	public Integer sectorSize;
	public Integer fatStart;
	public Integer dirStart;
	public Integer nDirEntries;
	
	public Fat (HierarchicalConfiguration<ImmutableNode> node) throws Exception {
		
		name = node.getString("[@name]", null);
		if (name == null) {
			throw new Exception("name is missing for fat");
		}
		
		sectorPerBlock = node.getInteger("[sectorperblock]", 0);
		if (sectorPerBlock == null) {
			throw new Exception("sectorperblock is missing for fat");
		}
		
		nBlocks = node.getInteger("[@nblocks]", null);
		if (nBlocks == null) {
			throw new Exception("@nblocks is missing for fat");
		}
		
		sectorSize = node.getInteger("[sectorsize]", null);
		if (sectorSize == null) {
			throw new Exception("sectorsize is missing for fat");
		}
		
		fatStart = node.getInteger("[fatstart]", null);
		if (fatStart == null) {
			throw new Exception("fatstart is missing for fat");
		}
		
		dirStart = node.getInteger("[dirstart]", null);
		if (dirStart == null) {
			throw new Exception("dirstart is missing for fat");
		}
		
		nDirEntries = node.getInteger("[ndirentries]", null);
		if (nDirEntries == null) {
			throw new Exception("ndirentries is missing for fat");
		}		
	}
}
