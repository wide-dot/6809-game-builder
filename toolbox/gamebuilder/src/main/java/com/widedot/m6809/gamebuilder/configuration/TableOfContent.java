package com.widedot.m6809.gamebuilder.configuration;

import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class TableOfContent {
	
	public String store;
	public String symbol;
	public String bin;
	public List<FileGroup> fileGroups;
	
	public TableOfContent(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		
		store = node.getString("[@store]", null);
		if (store == null) {
			throw new Exception("store is missing for toc");
		}

		symbol = node.getString("[@symbol]", null);
		if (store == null) {
			throw new Exception("symbol is missing for toc");
		}
		
		bin = node.getString("[@bin]", null);
		if (store == null) {
			throw new Exception("bin is missing for toc");
		}
		
		fileGroups = new ArrayList<FileGroup>();

	    List<HierarchicalConfiguration<ImmutableNode>> fgs = node.configurationsAt("filegroup");
    	for(HierarchicalConfiguration<ImmutableNode> fg : fgs)
    	{
   			fileGroups.add(new FileGroup(fg, path));
    	}
	}
}

