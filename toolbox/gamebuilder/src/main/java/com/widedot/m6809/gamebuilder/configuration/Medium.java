package com.widedot.m6809.gamebuilder.configuration;

import java.util.ArrayList;
import java.util.List;


import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import lombok.extern.slf4j.Slf4j;
@Slf4j
public class Medium {
	
	public String name;
	public String type;
	public String catalog;
	public List<Media> mediaList;
	
	public Medium(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		name = node.getString("[@name]", null);
		type = node.getString("[@type]", null);
		catalog = path + node.getString("[@catalog]", null);
		
		log.debug("name: "+name);
		log.debug("type: "+type);
		log.debug("catalog: "+catalog);
		
		mediaList = new ArrayList<Media>();
		
		// parse each media
	    List<HierarchicalConfiguration<ImmutableNode>> mediaFields = node.configurationsAt("media");
    	for(HierarchicalConfiguration<ImmutableNode> media : mediaFields)
    	{
    		mediaList.add(new Media(media, path));
    	}	
	}
}
