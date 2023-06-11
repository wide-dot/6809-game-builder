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
	
	public Target(String path) throws Exception {
		this.path = path;
	}
    
	public void process(HierarchicalConfiguration<ImmutableNode> target) throws Exception {
		String targetName = target.getString("[@name]");
		log.info("Processing target {}", target.getString("[@name]"));
		log.debug("name: "+targetName);
		GameBuilder gameBuilder = new GameBuilder(getDefines(target), getMedia(target), getStorages(target), path);
		log.info("End of processing target {}", target.getString("[@name]"));
	}

	private HashMap<String, String> getDefines(HierarchicalConfiguration<ImmutableNode> node) throws Exception {
		
	    HashMap<String, String> defines = new HashMap<String, String>();
		
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
	    		defines.put(symbol, value);
	    		log.debug(">> define");
	    		log.debug("   symbol: "+symbol);
	    		log.debug("   value: "+value);
	    	} 	
    	}	       	
    	return defines;
	}
	
	private List<Media> getMedia(HierarchicalConfiguration<ImmutableNode> node) throws Exception {
		
		List<Media> medias = new ArrayList<Media>();
		
		// parse each media
	    List<HierarchicalConfiguration<ImmutableNode>> mediaNodes = node.configurationsAt("media");
    	for(HierarchicalConfiguration<ImmutableNode> mediaNode : mediaNodes)
    	{
    		medias.add(new Media(mediaNode, path));
    	}	     
    	return medias;
	}

	private Storages getStorages(HierarchicalConfiguration<ImmutableNode> node) throws Exception {
		
		Storages storages = new Storages();
		
		// parse each media
	    List<HierarchicalConfiguration<ImmutableNode>> storageNodes = node.configurationsAt("storage");
	    for(HierarchicalConfiguration<ImmutableNode> storageNode : storageNodes)
    	{
	    	storages.add(storageNode, path);
    	}
	     
    	return storages;
	}
	
}
