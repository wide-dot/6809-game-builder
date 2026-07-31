package com.widedot.m6809.gamebuilder.spi.media;

public class DirEntry {
	public String name;
	public byte[] data;
	/** uncompressed content size in bytes ; 0 for an export-only file */
	public final int length;

	public DirEntry(String name, byte[] data, int length) {
		this.name = name;
		this.data = data;
		this.length = length;
	}
}
