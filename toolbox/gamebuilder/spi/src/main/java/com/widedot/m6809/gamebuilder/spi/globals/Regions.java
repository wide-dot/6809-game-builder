package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * The memory layout of a target : named regions at fixed destinations,
 * declared by the layout element and referenced by scene loads.
 *
 * A region is the point where scenes hand memory over to one another : every
 * scene loading into a region writes to the same page and address, which is
 * what makes the loader's implicit unload (exact destination match) evict the
 * previous content reliably.
 */
public class Regions {

	/** declaration order is kept for stable error messages */
	private final Map<String, Region> regions = new LinkedHashMap<String, Region>();

	public static class Region {
		public final String name;
		public final int page;
		public final int address;
		/** byte budget checked against the loaded entry, null means unchecked */
		public final Integer size;

		public Region(String name, int page, int address, Integer size) {
			this.name = name;
			this.page = page;
			this.address = address;
			this.size = size;
		}
	}

	public void put(Region region) throws Exception {
		if (regions.containsKey(region.name)) {
			throw new Exception("region '" + region.name + "' is declared twice");
		}
		regions.put(region.name, region);
	}

	public Region get(String name) {
		return regions.get(name);
	}

	public java.util.Collection<Region> all() {
		return regions.values();
	}

	public java.util.Set<String> names() {
		return regions.keySet();
	}

	public void clear() {
		regions.clear();
	}
}
