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

	/** symbol -> file whose link data carries the export, for the co-loadable rule */
	private final HashMap<String, String> exporterUnits = new HashMap<String, String>();

	/**
	 * The file being built, set by the file plugin. Export ownership is
	 * checked at the file granularity because that is the unit the loader
	 * loads and evicts.
	 */
	private String currentUnit = null;

	/**
	 * file -> sorted names of the exports its link data actually emits
	 * (post-prune). This is the run-time face of a file, compared between
	 * the alternatives of an interface region.
	 */
	public final HashMap<String, java.util.TreeSet<String>> unitExports = new HashMap<String, java.util.TreeSet<String>>();

	public void beginUnit(String file) {
		currentUnit = file;
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
	 * Several files MAY export the same name : the runtime resolves a symbol
	 * by scanning the loaded files and taking the first match
	 * (linkData.symbol.search), so whichever alternative is loaded wins.
	 * No co-loadability analysis is made here (author's arbitration,
	 * 2026-08-10) — the bake side refuses to resolve a multi-provider name
	 * at build time, and the caused list is where a name duplicated by
	 * mistake is seen.
	 *
	 * @param sym   exported symbol
	 * @param owner file that exports it, kept for the dangling-import report
	 */
	public int export(String sym, String owner) throws Exception {
		exporters.put(sym, owner);
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
		return unit == null ? "" : " (file " + unit + ")";
	}

	/**
	 * Every symbol still referenced through the loader has to be emitted by
	 * some file's link data.
	 *
	 * Dropping {@code linkdata} from a fully baked file is the last
	 * step of the {@code .static} policy, and it is the one step that can be
	 * taken too early : the day a consumer stops baking, its reference goes
	 * back through the loader, finds no export, and resolves to zero — the
	 * loader only complains when {@code loader.CHECK_UNRESOLVED_SYMBOLS} is
	 * defined, so the default is a program that loads, runs and reads address
	 * zero. That is the same silent shape {@code undefextern} was dropped for.
	 *
	 * Checked after the real pass, so it sees the post-prune truth.
	 */
	public void checkImportsResolvable() throws Exception {
		java.util.Set<String> emitted = new java.util.HashSet<String>();
		for (java.util.TreeSet<String> list : unitExports.values()) {
			emitted.addAll(list);
		}
		java.util.TreeSet<String> dangling = new java.util.TreeSet<String>();
		for (String sym : imports) {
			if (!emitted.contains(sym)) dangling.add(sym);
		}
		if (dangling.isEmpty()) return;

		StringBuilder m = new StringBuilder("symbols are referenced through the loader but"
				+ " no file emits them in its link data:");
		for (String sym : dangling) {
			String owner = exporters.get(sym);
			m.append(System.lineSeparator()).append("  ").append(sym);
			if (owner != null) {
				m.append(" — defined in ").append(owner).append(unitTag(exporterUnits.get(sym)))
				 .append(", which does not emit it");
			} else {
				// a file without linkdata never registers its exports
				// here at all, so this is the shape the mistake actually takes
				m.append(" — no file emits it : either the unit defining it"
						+ " lost its linkdata, or nothing defines it");
			}
		}
		m.append(System.lineSeparator())
		 .append("Either give that file its linkdata back, or bake the reference")
		 .append(" (bake=\"auto\" or \"all\") so it stops going through the loader.");
		log.error(m.toString());
		throw new Exception(m.toString());
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
