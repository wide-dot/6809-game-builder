package com.widedot.m6809.gamebuilder.configuration;

import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Media {
	
	public String storage;
	public List<FileGroup> fileGroups;
	public List<TableOfContent> tablesOfContent;
	
	public Media(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		
		storage = node.getString("[@storage]", null);
		if (storage == null) {
			throw new Exception("storage is missing for media");
		}
		
		fileGroups = new ArrayList<FileGroup>();

	    List<HierarchicalConfiguration<ImmutableNode>> fgs = node.configurationsAt("filegroup");
    	for(HierarchicalConfiguration<ImmutableNode> fg : fgs)
    	{
   			fileGroups.add(new FileGroup(fg, path));
    	}
    	
    	tablesOfContent = new ArrayList<TableOfContent>();

	    List<HierarchicalConfiguration<ImmutableNode>> tocs = node.configurationsAt("toc");
    	for(HierarchicalConfiguration<ImmutableNode> toc : tocs)
    	{
    		tablesOfContent.add(new TableOfContent(toc, path));
    	}    	
	}
}

