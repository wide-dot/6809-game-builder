package com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

public class Section {
	public String name;
	public int face;
	public int track;
	public int sector;
	
	public Section() {
		face = 0;
		track = 0;
		sector = 1;
	}
	
	public Section(HierarchicalConfiguration<ImmutableNode> node) throws Exception {
		name = node.getString("[@name]", null);
		if (name == null) {
			throw new Exception("name is missing for section");
		}

		face = node.getInteger("[@face]", -1);
		if (face == -1) {
			throw new Exception("face is missing for section");
		}
		
		track = node.getInteger("[@track]", -1);
		if (track == -1) {
			throw new Exception("track is missing for section");
		}
		
		sector = node.getInteger("[@sector]", -1);
		if (sector == -1) {
			throw new Exception("sector is missing for section");
		}
	}

	public Section(int face, int track, int sector) {
		this.face = face;
		this.track = track;
		this.sector = sector;
	}
	
	public Section(Section section) {
		this.face = section.face;
		this.track = section.track;
		this.sector = section.sector;
	}
	
}
