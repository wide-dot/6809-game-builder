package com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.configuration.NodeAttr;
import com.widedot.m6809.gamebuilder.spi.configuration.SourceMap;

public class Fat {

	public Integer sectorPerBlock;
	public Integer nBlocks;
	public Integer sectorSize;
	public Integer fatStart;
	public Integer dirStart;
	public Integer nDirEntries;

	public Fat(ImmutableNode node, SourceMap sources) throws Exception {
		// sectorperblock used to be read with a broken key ("[sectorperblock]",
		// missing @) and silently came out as 0 ; nothing consumes the fat
		// geometry yet, so reading it right changes no output
		sectorPerBlock = NodeAttr.getInteger(node, sources, "sectorperblock");
		nBlocks = NodeAttr.getInteger(node, sources, "nblocks");
		sectorSize = NodeAttr.getInteger(node, sources, "sectorsize");
		fatStart = NodeAttr.getInteger(node, sources, "fatstart");
		dirStart = NodeAttr.getInteger(node, sources, "dirstart");
		nDirEntries = NodeAttr.getInteger(node, sources, "ndirentries");
	}
}
