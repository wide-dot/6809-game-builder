package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.HashMap;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class LinkSymbols {
	public static HashMap<String, Integer> ids = new HashMap<String, Integer>();
	
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
	
	public static void clear() {
		ids.clear();
	}
}
