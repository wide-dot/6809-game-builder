package com.widedot.m6809.gamebuilder.configuration;

import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Media {
	
	public List<FileGroup> fileGroups;
	
	public Media(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		
		fileGroups = new ArrayList<FileGroup>();

	    List<HierarchicalConfiguration<ImmutableNode>> fgs = node.configurationsAt("filegroup");
    	for(HierarchicalConfiguration<ImmutableNode> fg : fgs)
    	{
   			fileGroups.add(new FileGroup(fg, path));
    	}
	}
}

