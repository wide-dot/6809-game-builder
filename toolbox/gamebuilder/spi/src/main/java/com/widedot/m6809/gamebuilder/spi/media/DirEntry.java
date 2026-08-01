package com.widedot.m6809.gamebuilder.spi.media;

import java.util.Collections;
import java.util.Map;

public class DirEntry {
	public String name;
	public byte[] data;
	/** uncompressed content size in bytes ; 0 for an export-only file */
	public final int length;
	/**
	 * Ranges that must stay inside one 256 byte page once loaded, by tag, as
	 * offsets in the file. Checked against the destination when a scene places
	 * this entry — until then nothing knows where it lands.
	 */
	public final Map<String, int[]> pageSpans;

	public DirEntry(String name, byte[] data, int length) {
		this(name, data, length, Collections.<String, int[]>emptyMap());
	}

	public DirEntry(String name, byte[] data, int length, Map<String, int[]> pageSpans) {
		this.name = name;
		this.data = data;
		this.length = length;
		this.pageSpans = pageSpans;
	}
}
