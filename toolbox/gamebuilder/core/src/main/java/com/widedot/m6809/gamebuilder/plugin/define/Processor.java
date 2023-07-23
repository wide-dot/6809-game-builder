package com.widedot.m6809.gamebuilder.plugin.define;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	
	public static void run(ImmutableNode node, String path, Defaults defaults, Defines defines) throws Exception {
    	
		log.debug("Processing define ...");
		
   		String symbol = (String) node.getAttributes().get("symbol");
   		String value = (String) node.getAttributes().get("value");
   		defines.values.put(symbol, value);
   		log.debug("default symbol: {} value: {}", symbol, value);
		
		log.debug("End of processing define");
	}
	
}
