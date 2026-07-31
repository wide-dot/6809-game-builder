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
	
	public int add(String sym) throws Exception {
		
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
		String previous = exporters.put(sym, owner);
		if (previous != null && !previous.equals(owner)) {
			String m = "symbol " + sym + " is exported by both " + previous + " and " + owner
					+ " ; exported symbols must be unique across a project, the loader"
					+ " resolves them by scanning loaded files and takes the first match";
			log.error(m);
			throw new Exception(m);
		}
		return add(sym);
	}

	public void clear() {
		ids.clear();
		exporters.clear();
	}
}
