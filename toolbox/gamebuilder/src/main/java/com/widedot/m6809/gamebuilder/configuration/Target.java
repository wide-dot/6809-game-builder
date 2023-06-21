package com.widedot.m6809.gamebuilder.configuration;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.builder.GameBuilder;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Target {
	
	public String path;
	List<Media> medias;
	public Defines defines;
	public Defaults defaults;
	public Storages storages;
	
	public Target(String path) throws Exception {
		this.path = path;
		medias = new ArrayList<Media>();
		defines = new Defines();
		defaults = new Defaults();
		storages = new Storages();
	}
    
	public void process(HierarchicalConfiguration<ImmutableNode> target) throws Exception {
		String targetName = target.getString("[@name]");
		
		log.info("Processing target {}", targetName);
		
		defines.add(target);
		defaults.add(target);

		// parse each file of storage definition in a single object
	    List<HierarchicalConfiguration<ImmutableNode>> storageNodes = target.configurationsAt("storage");
	    for(HierarchicalConfiguration<ImmutableNode> storageNode : storageNodes)
    	{
	    	storages.add(storageNode, path);
    	}
		
		// parse each media
	    List<HierarchicalConfiguration<ImmutableNode>> mediaNodes = target.configurationsAt("media");
    	for(HierarchicalConfiguration<ImmutableNode> mediaNode : mediaNodes)
    	{
    		medias.add(new Media(mediaNode, path));
    	}	
		
		new GameBuilder(medias, storages, defines.values, defaults.values, path);
		log.info("End of processing target {}", target.getString("[@name]"));
	}
}
