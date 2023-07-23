package com.widedot.m6809.gamebuilder.plugin.defaults;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	
	public static void run(ImmutableNode node, String path, Defaults defaults, Defines defines) throws Exception {
    	
		log.debug("Processing default ...");
		
   		String name = (String) node.getAttributes().get("name");
   		String value = (String) node.getAttributes().get("value");
   		defaults.values.put(name, value);
   		log.debug("default name: {} value: {}", name, value);
		
		log.debug("End of processing default");
	}
	
}
