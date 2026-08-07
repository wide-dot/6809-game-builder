package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * What the build physically wrote, collected for the occupancy report.
 *
 * Two families of facts, matching the report's two views :
 *
 * <ul>
 * <li><b>Media</b> — every byte range written to a media instance (a disk),
 * with the section it went to and the name of what it carries. Recorded at
 * the single place that knows the geometry : the media implementation.</li>
 * <li><b>File sizes</b> — the uncompressed size of every directory entry.
 * Crossed with {@link RamMap} at render time, this is what tells the files
 * that never land anywhere in RAM : they are listed apart, with their
 * size, instead of silently missing from the picture.</li>
 * </ul>
 *
 * The RAM half of the report needs no collection of its own : {@link RamMap}
 * (where each scene loads each file) and {@link Regions} (reserved ranges)
 * already hold it.
 */
public class Occupancy {

	/** one contiguous byte range written to a media instance */
	public static class MediaWrite {
		public final String instance;
		public final String section;
		/** first byte on the media, in raw image order */
		public final int start;
		public final int length;
		/** what these bytes carry — a file name, "directory 0", "boot"… */
		public final String name;

		public MediaWrite(String instance, String section, int start, int length, String name) {
			this.instance = instance;
			this.section = section;
			this.start = start;
			this.length = length;
			this.name = name;
		}
	}

	/** a media instance : its capacity, and the geometry its bytes follow */
	public static class Instance {
		public final String name;
		public final int capacity;
		public final int faces;
		public final int tracks;
		public final int sectors;
		public final int sectorSize;

		public Instance(String name, int capacity, int faces, int tracks, int sectors,
				int sectorSize) {
			this.name = name;
			this.capacity = capacity;
			this.faces = faces;
			this.tracks = tracks;
			this.sectors = sectors;
			this.sectorSize = sectorSize;
		}
	}

	private final Map<String, Instance> instances = new LinkedHashMap<String, Instance>();
	private final List<MediaWrite> writes = new ArrayList<MediaWrite>();
	private final Map<String, Integer> fileSizes = new LinkedHashMap<String, Integer>();

	/**
	 * Declaring an instance forgets its earlier writes : the build runs
	 * several passes and each one rebuilds the same disk — without this,
	 * every byte range appeared once per pass.
	 */
	public void declareInstance(Instance instance) {
		instances.put(instance.name, instance);
		writes.removeIf(w -> w.instance.equals(instance.name));
	}

	public void write(MediaWrite write) {
		writes.add(write);
	}

	public void fileSize(String name, int size) {
		fileSizes.put(name, size);
	}

	/** media instances, in declaration order */
	public Map<String, Instance> instances() {
		return Collections.unmodifiableMap(instances);
	}

	public List<MediaWrite> writes() {
		return Collections.unmodifiableList(writes);
	}

	/** every directory entry ever built, name -> uncompressed size */
	public Map<String, Integer> fileSizes() {
		return Collections.unmodifiableMap(fileSizes);
	}

	public boolean isEmpty() {
		return instances.isEmpty() && writes.isEmpty() && fileSizes.isEmpty();
	}

	public void clear() {
		instances.clear();
		writes.clear();
		fileSizes.clear();
	}
}
