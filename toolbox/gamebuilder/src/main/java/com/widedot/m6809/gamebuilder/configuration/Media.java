package com.widedot.m6809.gamebuilder.configuration;

import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import lombok.extern.slf4j.Slf4j;

public class Media {
	
	public String storage;
	public List<LwAsm> lwasms;
	public List<Index> indexes;
	
	public Media(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		
		storage = node.getString("[@storage]", null);
		if (storage == null) {
			throw new Exception("storage is missing for media");
		}
		
		lwasms = new ArrayList<LwAsm>();

	    List<HierarchicalConfiguration<ImmutableNode>> lwasmList = node.configurationsAt("lwasm");
    	for(HierarchicalConfiguration<ImmutableNode> lwasm : lwasmList)
    	{
   			lwasms.add(new LwAsm(lwasm, path));
    	}
    	
    	indexes = new ArrayList<Index>();

	    List<HierarchicalConfiguration<ImmutableNode>> indexList = node.configurationsAt("index");
    	for(HierarchicalConfiguration<ImmutableNode> index : indexList)
    	{
    		indexes.add(new Index(index, path));
    	}    	
	}
}

