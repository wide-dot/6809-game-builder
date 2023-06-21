package com.widedot.m6809.gamebuilder.configuration.storage;

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
	
	public Section(Section section) {
		this.face = section.face;
		this.track = section.track;
		this.sector = section.sector;
	}
}
