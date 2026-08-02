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
		/**
		 * bulk : the region takes a whole list of loads per scene, laid out
		 * one after the other at run time. Members give up individual
		 * replaceability — the list is the unit of replacement.
		 */
		public final boolean bulk;
		/**
		 * How many consecutive pages the region spans, starting at page. One
		 * for an ordinary region ; more makes room for a dataset no single
		 * page can hold, which a pageset fills — the author declares the
		 * budget, the builder decides what lands where.
		 */
		public final int pages;

		public Region(String name, int page, int address, Integer size, boolean bulk,
				int pages) {
			this.name = name;
			this.page = page;
			this.address = address;
			this.size = size;
			this.bulk = bulk;
			this.pages = pages;
		}
	}

	/**
	 * A range the game occupies without ever loading anything into it : the
	 * object pool, the inter-main globals, the stack, the direct page. The
	 * builder cannot infer them — they are equates in the game's source — so
	 * the layout declares them and nothing may be loaded on top.
	 */
	public static class Reserved {
		public final String name;
		public final int page;
		public final int address;
		public final int size;

		public Reserved(String name, int page, int address, int size) {
			this.name = name;
			this.page = page;
			this.address = address;
			this.size = size;
		}
	}

	private final java.util.List<Reserved> reserved = new java.util.ArrayList<Reserved>();

	public void reserve(Reserved range) {
		reserved.add(range);
	}

	public java.util.List<Reserved> reservedRanges() {
		return reserved;
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

	public void clearReserved() {
		reserved.clear();
	}

	public void clear() {
		reserved.clear();
		regions.clear();
	}
}
