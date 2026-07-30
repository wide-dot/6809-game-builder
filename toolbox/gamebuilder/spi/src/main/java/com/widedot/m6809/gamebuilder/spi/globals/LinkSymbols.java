package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.HashMap;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class LinkSymbols {
	public static HashMap<String, Integer> ids = new HashMap<String, Integer>();

	/**
	 * symbol -> file that exports it.
	 *
	 * Note on ids: they are handed out in order of first appearance. That is
	 * deterministic as long as the build walks its inputs in a fixed order,
	 * which it now does. Sorting them alphabetically, as the original design
	 * notes ask, is only required for group interfaces (several groups sharing
	 * one export list and therefore one set of indexes) and is deferred with
	 * that feature ; it would need a collect pass before any emission.
	 */
	private static HashMap<String, String> exporters = new HashMap<String, String>();
	
	public static int add(String sym) throws Exception {
		
		int nbSymbols;
		
		// assign a global key to this symbol
	    if (!LinkSymbols.ids.containsKey(sym)) {
	    	
	    	nbSymbols = LinkSymbols.ids.size();
	    	if (nbSymbols==0x10000) {
				String m = "Too many exported symbols ! limited to " + nbSymbols;
				log.error(m);
				throw new Exception(m);
	    	}
	    	
	    	LinkSymbols.ids.put(sym, nbSymbols);
	        //log.debug("link id for symbol {} : {} (new id)", sym, nbSymbols);
	    } else {
	    	nbSymbols = LinkSymbols.ids.get(sym);
	    	//log.debug("link id for symbol {} : {} (existing id)", sym, LinkSymbols.ids.get(sym));
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
	public static int export(String sym, String owner) throws Exception {
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

	public static void clear() {
		ids.clear();
		exporters.clear();
	}
}
