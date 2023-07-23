package com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;

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
	
	public Section(ImmutableNode node) throws Exception {
		setAttributes(node, (Defaults)null);
	}
	
	public Section(ImmutableNode node, Defaults defaults) throws Exception {
		setAttributes(node, defaults);
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
	
	private void setAttributes(ImmutableNode node, Defaults defaults) throws Exception {
		name = Attribute.getString(node, defaults, "name", "floppydisk.section.name");
		face = Attribute.getInteger(node, defaults, "face", "floppydisk.section.face");
		track = Attribute.getInteger(node, defaults, "track", "floppydisk.section.track");
		sector = Attribute.getInteger(node, defaults, "sector", "floppydisk.section.sector");
	}
	
}
