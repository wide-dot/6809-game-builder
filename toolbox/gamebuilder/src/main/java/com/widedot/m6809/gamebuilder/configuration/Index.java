package com.widedot.m6809.gamebuilder.configuration;

import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Index {
	
	public String section;
	public String symbol;
	public String bin;
	public List<LwAsm> lwasms;
	
	public Index(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		
		section = node.getString("[@section]", null);
		if (section == null) {
			throw new Exception("section is missing for index");
		}

		symbol = node.getString("[@symbol]", null);
		if (symbol == null) {
			throw new Exception("symbol is missing for index");
		}
		
		lwasms = new ArrayList<LwAsm>();

	    List<HierarchicalConfiguration<ImmutableNode>> lwasmList = node.configurationsAt("lwasm");
    	for(HierarchicalConfiguration<ImmutableNode> lwasm : lwasmList)
    	{
   			lwasms.add(new LwAsm(lwasm, path));
    	}
	}
}

