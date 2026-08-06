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
		 * stacked : the region takes a whole list of loads per scene, laid
		 * out one after the other at run time. Members give up individual
		 * replaceability — the list is the unit of replacement.
		 */
		public final boolean stacked;
		/**
		 * How many consecutive pages the region spans, starting at page. One
		 * for an ordinary region ; more makes room for a dataset no single
		 * page can hold, which a pageset fills — the author declares the
		 * budget, the builder decides what lands where.
		 */
		public final int pages;

		public Region(String name, int page, int address, Integer size, boolean stacked,
				int pages) {
			this.name = name;
			this.page = page;
			this.address = address;
			this.size = size;
			this.stacked = stacked;
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

	/**
	 * A window the machine can see a page through.
	 *
	 * A page is 16 KB of RAM ; WHERE the CPU sees it is a property of the
	 * machine, not of the layout — on a TO8 the cartridge window opens at
	 * $0000, the resident RAM at $6000, the bank at $A000. The layout used to
	 * say nothing about it, so nobody could tell how much room was left above
	 * the last region of a page : the occupancy report showed regions at 100%
	 * (a size="auto" region always fills itself) while thousands of bytes sat
	 * unused above them.
	 *
	 * Declaring the windows costs three lines and buys two things : the report
	 * can name the free tail of every page, and a region that would run past
	 * the end of its window is refused at build time instead of overwriting
	 * whatever the hardware maps next.
	 */
	public static class Window {
		public final String name;
		public final int address;
		public final int size;

		public Window(String name, int address, int size) {
			this.name = name;
			this.address = address;
			this.size = size;
		}

		public boolean holds(int addr) {
			return addr >= address && addr < address + size;
		}

		public int end() {
			return address + size;
		}
	}

	private final java.util.List<Window> windows = new java.util.ArrayList<Window>();

	public void addWindow(Window window) {
		windows.add(window);
	}

	public void clearWindows() {
		windows.clear();
	}

	public java.util.List<Window> windows() {
		return windows;
	}

	/** the window an address is seen through, or null when none is declared */
	public Window windowOf(int address) {
		for (Window w : windows) {
			if (w.holds(address)) {
				return w;
			}
		}
		return null;
	}

	private final java.util.List<Reserved> reserved = new java.util.ArrayList<Reserved>();

	public void reserve(Reserved range) {
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

	/**
	 * Region name -> how many pages its pageset really filled, recorded as the
	 * set is packed. The counterpart of {@code measured} for {@code pages="auto"} :
	 * a page budget is a number the author guesses just as badly as a size, and
	 * the packer knows the answer the moment it has packed.
	 */
	private final Map<String, Integer> pagesUsed = new LinkedHashMap<String, Integer>();
	private Map<String, Integer> measuredPages = new LinkedHashMap<String, Integer>();

	/**
	 * The LARGEST, not the last : a region hosting alternatives is targeted by
	 * one pageset per alternative — stage 1's tileset and stage 2's — and it
	 * has to be sized for the biggest of them. Keeping the last one packed
	 * makes the build refuse the other, which is how this was found.
	 */
	public void recordPagesUsed(String region, int pages) {
		Integer known = pagesUsed.get(region);
		if (known == null || pages > known) {
			pagesUsed.put(region, pages);
		}
	}

	public Map<String, Integer> pagesUsedSnapshot() {
		return new LinkedHashMap<String, Integer>(pagesUsed);
	}

	public void seedMeasuredPages(Map<String, Integer> pages) {
		measuredPages = new LinkedHashMap<String, Integer>(pages);
	}

	/** how many pages this region's content needed, or null when unmeasured */
	public Integer measuredPages(String name) {
		return measuredPages.get(name);
	}

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
		windows.clear();
		measured.clear();
		pagesUsed.clear();
		measuredPages.clear();
		reserved.clear();
		regions.clear();
	}
}
