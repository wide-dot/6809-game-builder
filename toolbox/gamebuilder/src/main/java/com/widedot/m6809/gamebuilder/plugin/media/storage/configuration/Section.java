package com.widedot.m6809.gamebuilder.plugin.media.storage.configuration;

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
