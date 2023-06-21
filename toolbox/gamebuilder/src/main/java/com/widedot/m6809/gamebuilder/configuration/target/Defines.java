package com.widedot.m6809.gamebuilder.configuration.target;

import java.util.HashMap;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Defines {

	public HashMap<String, String> values;
	
	public Defines() {
		values = new HashMap<String, String>();
	}
	
	public void add(HierarchicalConfiguration<ImmutableNode> node) throws Exception {
		
		// parse each defines
	    List<HierarchicalConfiguration<ImmutableNode>> definesNodes = node.configurationsAt("defines");
    	for(HierarchicalConfiguration<ImmutableNode> definesNode : definesNodes)
    	{
    		// parse each define inside defines
		    List<HierarchicalConfiguration<ImmutableNode>> defineNodes = definesNode.configurationsAt("define");
	    	for(HierarchicalConfiguration<ImmutableNode> defineNode : defineNodes)
	    	{
	    		String symbol = defineNode.getString("[@symbol]", null);
	    		String value = defineNode.getString("[@value]", null);
	    		values.put(symbol, value);
	    		log.debug("symbol: {} value: {}", symbol, value);
	    	} 	
    	}	      
	}
	
}
