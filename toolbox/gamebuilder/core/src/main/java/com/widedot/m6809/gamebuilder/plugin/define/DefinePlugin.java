package com.widedot.m6809.gamebuilder.plugin.define;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class DefinePlugin {
	
	public static void run(ImmutableNode node, String path, Defaults defaults, Defines defines) throws Exception {
    	
		log.debug("Processing define ...");
		
   		String symbol = (String) node.getAttributes().get("symbol");
   		String value = Attribute.getString(node, defaults, "value", "defines.value", "1", true);
   		defines.values.put(symbol, value);
   		log.debug("define symbol: {} value: {}", symbol, value);
		
		log.debug("End of processing define");
	}
	
}
