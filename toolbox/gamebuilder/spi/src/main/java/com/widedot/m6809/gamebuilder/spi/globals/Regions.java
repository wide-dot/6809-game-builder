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

	/**
	 * A continuous range inside ONE page — the only thing in a layout that
	 * speaks of physical memory, and it speaks of nothing else.
	 *
	 * Never spans pages : declaring several zones is exactly how a discontinuous
	 * space is described, and a zone that straddled a page boundary would make
	 * that impossible to express.
	 */
	public static class Zone {
		public final int page;
		public final int address;
		public final int size;

		public Zone(int page, int address, int size) {
			this.page = page;
			this.address = address;
			this.size = size;
		}

		public int end() {
			return address + size;
		}
	}

	public static class Region {
		public final String name;
		public final int page;
		public final int address;
		/** byte budget checked against the loaded entry, null means unchecked */
		public final Integer size;
		/**
		 * How many consecutive pages the region spans, starting at page. One
		 * for an ordinary region ; more makes room for a dataset no single
		 * page can hold, which a pageset fills — the author declares the
		 * budget, the builder decides what lands where.
		 */
		public final int pages;

		/**
		 * Where this region physically lives. A region declared the compact way
		 * — page, address and size on the element itself — holds exactly one
		 * zone, built from those attributes : the compact form is not a special
		 * case in the code, only a shorthand in the file.
		 */
		public final java.util.List<Zone> zones;

		/**
		 * An ARENA : the builder ranges the files over the zones instead of
		 * taking them in declaration order. Nothing outside may bake an address
		 * into a file that lives here — it is reached through a table, which is
		 * what lets it move.
		 */
		public final boolean packed;

		public Region(String name, int page, int address, Integer size, int pages) {
			this(name, page, address, size, pages, null, false);
		}

		public Region(String name, int page, int address, Integer size, int pages,
				java.util.List<Zone> zones) {
			this(name, page, address, size, pages, zones, false);
		}

		public Region(String name, int page, int address, Integer size, int pages,
				java.util.List<Zone> zones, boolean packed) {
			this.packed = packed;
			this.name = name;
			this.page = page;
			this.address = address;
			this.size = size;
			this.pages = pages;
			if (zones != null && !zones.isEmpty()) {
				this.zones = java.util.Collections.unmodifiableList(
						new java.util.ArrayList<Zone>(zones));
			} else if (size != null) {
				// the compact form, including its multi-page spelling : N
				// consecutive pages of the same size is exactly N zones, and
				// saying it that way keeps one shape downstream
				java.util.List<Zone> built = new java.util.ArrayList<Zone>();
				for (int p = 0; p < Math.max(1, pages); p++) {
					built.add(new Zone(page + p, address, size));
				}
				this.zones = java.util.Collections.unmodifiableList(built);
			} else {
				this.zones = java.util.Collections.emptyList();
			}
		}

		/** total room this region offers, across all its zones */
		public int capacity() {
			int total = 0;
			for (Zone z : zones) {
				total += z.size;
			}
			return total;
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

	/**
	 * How many pages of physical RAM the machine has — the vertical extent of
	 * the occupancy report's RAM view. 32 pages of 16 KB (a 512K TO8) unless
	 * the layout says otherwise ({@code <layout pages="8">} for a 128K MO6).
	 */
	private int ramPages = 32;

	public void setRamPages(int pages) {
		this.ramPages = pages;
	}

	public int ramPages() {
		return ramPages;
	}

	private final java.util.List<Reserved> reserved = new java.util.ArrayList<Reserved>();

	/**
	 * Idempotent by name : the build runs several passes and each one declares
	 * the same ranges — the last declaration wins, which also lets a measured
	 * reservation (the loader) replace itself as its size settles.
	 */
	public void reserve(Reserved range) {
		reserved.removeIf(r -> r.name.equals(range.name));
		reserved.add(range);
	}

	public java.util.List<Reserved> reservedRanges() {
		return reserved;
	}

	/**
	 * Region name -> the size its content measured during the discovery pass.
	 * Seeded into the real pass, where {@code size="auto"} reads it. Empty
	 * during discovery itself : nothing has been measured yet, and the
	 * resolver falls back on the whole page.
	 */
	private Map<String, Integer> measured = new LinkedHashMap<String, Integer>();

	public void seedMeasured(Map<String, Integer> sizes) {
		measured = new LinkedHashMap<String, Integer>(sizes);
	}

	/** the measured size of a region's content, or null when unmeasured */
	public Integer measured(String name) {
		return measured.get(name);
	}

	public boolean hasMeasures() {
		return !measured.isEmpty();
	}

	/**
	 * File name -> the size it measured, harvested by the discovery pass.
	 * An arena cannot range anything without it : the size of a file is only
	 * known once it has been built, and the placement has to be known before.
	 */
	private Map<String, Integer> fileSizes = new LinkedHashMap<String, Integer>();

	/** File name -> {page, address}, decided by the arena packer. */
	private final Map<String, int[]> filePlacements = new LinkedHashMap<String, int[]>();

	/**
	 * Arena name -> the free ranges its rigid placement left, {page, address,
	 * size} in zone order. This is what a collection flows into : the packer
	 * records what remains after the rigid files are placed, and each pageset
	 * that flows consumes its share and stores the rest back. Absent (null)
	 * when nothing was recorded — the discovery pass, or an arena holding no
	 * rigid file — in which case the whole zones are the gaps.
	 */
	private final Map<String, java.util.List<int[]>> arenaGaps =
			new LinkedHashMap<String, java.util.List<int[]>>();

	public void setArenaGaps(String arena, java.util.List<int[]> gaps) {
		arenaGaps.put(arena, gaps);
	}

	/** the recorded free ranges of an arena, or null when none were recorded */
	public java.util.List<int[]> arenaGaps(String arena) {
		return arenaGaps.get(arena);
	}

	public void seedFileSizes(Map<String, Integer> sizes) {
		fileSizes = new LinkedHashMap<String, Integer>(sizes);
	}

	public Integer fileSize(String file) {
		return fileSizes.get(file);
	}

	public void placeFile(String file, int page, int address) {
		filePlacements.put(file, new int[] { page, address });
	}

	/** where the packer put this file, or null when no arena holds it */
	public int[] filePlacement(String file) {
		return filePlacements.get(file);
	}

	public Map<String, int[]> filePlacements() {
		return filePlacements;
	}

	public void clearFilePlacements() {
		filePlacements.clear();
		arenaGaps.clear();
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
		ramPages = 32;
		fileSizes.clear();
		filePlacements.clear();
		arenaGaps.clear();
		measured.clear();
		reserved.clear();
		regions.clear();
	}
}
