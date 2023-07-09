package com.widedot.m6809.gamebuilder.configuration.common;

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
		log.debug("Reading define values ...");
	    List<HierarchicalConfiguration<ImmutableNode>> defineNodes = node.configurationsAt("define");
    	for(HierarchicalConfiguration<ImmutableNode> defineNode : defineNodes)
    	{
    		String symbol = defineNode.getString("[@symbol]", null);
    		String value = defineNode.getString("[@value]", null);
    		values.put(symbol, value);
    		log.debug("define symbol: {} value: {}", symbol, value);
    	} 	
	}
}
