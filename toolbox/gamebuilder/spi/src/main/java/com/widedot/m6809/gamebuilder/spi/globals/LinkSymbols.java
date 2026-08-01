package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.HashMap;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class LinkSymbols {
	public final HashMap<String, Integer> ids = new HashMap<String, Integer>();

	/**
	 * symbol -> file that exports it.
	 *
	 * Note on ids: within one pass they are handed out in order of first
	 * appearance, but the build runs a discovery pass first and preseeds this
	 * table with the full symbol set sorted alphabetically (see Target). Ids
	 * therefore depend on the symbol NAMES only : reordering sources or
	 * members no longer renumbers everything, which keeps binary comparison a
	 * meaningful signal and is the prerequisite of group interfaces.
	 */
	private final HashMap<String, String> exporters = new HashMap<String, String>();

	/** symbol -> direntry whose link data carries the export, for the co-loadable rule */
	private final HashMap<String, String> exporterUnits = new HashMap<String, String>();

	/**
	 * The direntry being built, set by the direntry plugin. Export ownership is
	 * checked at the direntry granularity because that is the unit the loader
	 * loads and evicts.
	 */
	private String currentUnit = null;

	/**
	 * The target's scene placements, wired by the build context. Two direntries
	 * loaded at the same exact destination are mutually exclusive at run time —
	 * registering one evicts the other from the loader's index (implicit unload
	 * by destination) — so their exports may share names.
	 */
	public StaticLink placements = null;

	/**
	 * direntry -> sorted names of the exports its link data actually emits
	 * (post-prune). This is the run-time face of a direntry, compared between
	 * the alternatives of an interface region.
	 */
	public final HashMap<String, java.util.TreeSet<String>> unitExports = new HashMap<String, java.util.TreeSet<String>>();

	public void beginUnit(String direntry) {
		currentUnit = direntry;
	}

	/**
	 * Symbols some unit actually references as EXTERNAL. Filled during the
	 * discovery pass ; the real pass prunes the exports nobody is in.
	 */
	public final java.util.HashSet<String> imports = new java.util.HashSet<String>();

	/**
	 * The import set the discovery pass collected, when pruning is active for
	 * this pass ; null means emit every export (the discovery pass itself).
	 */
	private java.util.Set<String> emittedExports = null;

	/** exports the real pass left out of the link data, for the report */
	public int pruned = 0;

	/**
	 * Assigns ids 0..n-1 to the given symbols, in list order. Called with the
	 * alphabetically sorted symbol set collected by the discovery pass ;
	 * symbols first seen after this (a config error path) get the next free
	 * ids in appearance order.
	 */
	public void preseed(java.util.List<String> symbols) {
		for (String sym : symbols) {
			ids.put(sym, ids.size());
		}
	}
	
	/** the discovery pass hands its import set over ; pruning starts here */
	public void preseedImports(java.util.Set<String> imported) {
		emittedExports = new java.util.HashSet<String>(imported);
	}

	/**
	 * Whether an export earns its bytes in the link data. Everything does
	 * until a discovery pass has said who is actually imported : the loader
	 * resolves references by scanning export tables, so an export nobody
	 * references is pure search overhead.
	 */
	public boolean isEmitted(String sym) {
		return emittedExports == null || emittedExports.contains(sym);
	}

	/** a unit references sym as an external : id, and a seat at the table */
	public int add(String sym) throws Exception {
		imports.add(sym);
		return idOf(sym);
	}

	private int idOf(String sym) throws Exception {
		
		int nbSymbols;
		
		// assign a global key to this symbol
	    if (!ids.containsKey(sym)) {
	    	
	    	nbSymbols = ids.size();
	    	if (nbSymbols==0x10000) {
				String m = "Too many exported symbols ! limited to " + nbSymbols;
				log.error(m);
				throw new Exception(m);
	    	}
	    	
	    	ids.put(sym, nbSymbols);
	        //log.debug("link id for symbol {} : {} (new id)", sym, nbSymbols);
	    } else {
	    	nbSymbols = ids.get(sym);
	    	//log.debug("link id for symbol {} : {} (existing id)", sym, ids.get(sym));
	    }
	    
	    return nbSymbols;
	}
	
	/**
	 * Records that a file exports a symbol, and returns its link id.
	 *
	 * The runtime resolves a symbol by scanning the loaded files and taking the
	 * first match (linkData.symbol.search), so two files exporting the same name
	 * would resolve differently depending on load order. Rejecting it here is
	 * what makes the resolution unambiguous.
	 *
	 * @param sym   exported symbol
	 * @param owner file that exports it, used for the error message
	 */
	public int export(String sym, String owner) throws Exception {
		String previousUnit = exporterUnits.get(sym);
		String previous = exporters.put(sym, owner);
		boolean sameOwner = previous == null
				|| (previous.equals(owner) && java.util.Objects.equals(previousUnit, currentUnit));
		if (!sameOwner) {
			// uniqueness is required per co-loadable set, not per project : two
			// direntries loaded at the same exact destination can never be in
			// the loader's index together (registering one evicts the other),
			// so the scan-first-match resolution stays unambiguous
			boolean alternatives = previousUnit != null && currentUnit != null
					&& !previousUnit.equals(currentUnit)
					&& placements != null
					&& placements.sameSingleDestination(previousUnit, currentUnit);
			if (!alternatives) {
				String m = "symbol " + sym + " is exported by both " + previous
						+ unitTag(previousUnit) + " and " + owner + unitTag(currentUnit)
						+ " ; exported symbols must be unique across the direntries that can"
						+ " be loaded together — the loader resolves them by scanning loaded"
						+ " files and takes the first match. Only direntries every scene loads"
						+ " at the same exact destination may share names, being mutually"
						+ " exclusive at run time";
				log.error(m);
				throw new Exception(m);
			}
			log.debug("symbol {} exported by both {} and {} : direntries at the same"
					+ " destination, mutually exclusive at run time", sym, previousUnit, currentUnit);
		}
		exporterUnits.put(sym, currentUnit);
		if (currentUnit != null && isEmitted(sym)) {
			java.util.TreeSet<String> list = unitExports.get(currentUnit);
			if (list == null) {
				list = new java.util.TreeSet<String>();
				unitExports.put(currentUnit, list);
			}
			list.add(sym);
		}
		return idOf(sym);
	}

	private static String unitTag(String unit) {
		return unit == null ? "" : " (direntry " + unit + ")";
	}

	public void clear() {
		ids.clear();
		exporters.clear();
		exporterUnits.clear();
		unitExports.clear();
		currentUnit = null;
		imports.clear();
		emittedExports = null;
		pruned = 0;
	}
}
