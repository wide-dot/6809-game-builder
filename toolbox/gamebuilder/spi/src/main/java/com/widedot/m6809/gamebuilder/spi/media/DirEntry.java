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

	/**
	 * A payload this entry still has to put on the media : the entry is built
	 * before anything knows which scene reads it first, so the bytes wait here
	 * and the directory flushes them in first-use order — the disk order
	 * becomes a projection of the scenes instead of the declaration order.
	 * The 6 byte location descriptor cwrite returns is patched into
	 * {@link #data} at {@code patchOffset} when the flush happens.
	 */
	public static class Pending {
		public final String section;
		public final byte[] bytes;
		public final String name;
		public final int patchOffset;

		public Pending(String section, byte[] bytes, String name, int patchOffset) {
			this.section = section;
			this.bytes = bytes;
			this.name = name;
			this.patchOffset = patchOffset;
		}
	}

	/** payloads to flush, in this entry's own order (data before link data) */
	public final java.util.List<Pending> pending = new java.util.ArrayList<Pending>();

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
