package com.widedot.m6809.gamebuilder.spi.media;

public class DirEntry {
	public String name;
	public byte[] data;
	
	public DirEntry(String name, byte[] data) {
		this.name = name;
		this.data = data;
	}
}
