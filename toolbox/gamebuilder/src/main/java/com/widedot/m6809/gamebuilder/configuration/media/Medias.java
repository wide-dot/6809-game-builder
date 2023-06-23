package com.widedot.m6809.gamebuilder.configuration.media;

import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.configuration.target.Defaults;

public class Medias {

	public List<Media> mediaList;
	
	public Medias() {
		mediaList = new ArrayList<Media>();
	}
	
	public void add(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults) throws Exception {
	    List<HierarchicalConfiguration<ImmutableNode>> mediaNodes = node.configurationsAt("media");
    	for(HierarchicalConfiguration<ImmutableNode> mediaNode : mediaNodes)
    	{
    		mediaList.add(new Media(mediaNode, path, defaults));
    	}	
	}
	
}
