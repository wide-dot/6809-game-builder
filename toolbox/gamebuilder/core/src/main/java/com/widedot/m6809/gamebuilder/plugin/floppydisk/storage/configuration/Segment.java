package com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.configuration.NodeAttr;
import com.widedot.m6809.gamebuilder.spi.configuration.SourceMap;

public class Segment {
	public int faces;
	public int facesSize;
	public int tracks;
	public int tracksSize;
	public int sectors;
	public int sectorSize;

	public Segment(ImmutableNode node, SourceMap sources) throws Exception {
		faces = NodeAttr.getInteger(node, sources, "faces");
		tracks = NodeAttr.getInteger(node, sources, "tracks");
		sectors = NodeAttr.getInteger(node, sources, "sectors");
		sectorSize = NodeAttr.getInteger(node, sources, "sectorSize");

		facesSize = faces * tracks * sectors * sectorSize;
		tracksSize = tracks * sectors * sectorSize;
	}
}
