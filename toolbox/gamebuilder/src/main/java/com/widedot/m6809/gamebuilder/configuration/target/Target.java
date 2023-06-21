package com.widedot.m6809.gamebuilder.configuration.target;

import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.builder.GameBuilder;
import com.widedot.m6809.gamebuilder.configuration.media.Medias;
import com.widedot.m6809.gamebuilder.configuration.storage.Storages;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Target {
	
	public String path;
	public Medias medias;
	public Defines defines;
	public Defaults defaults;
	public Storages storages;
	
	public Target(String path) throws Exception {
		this.path = path;
		medias = new Medias();
		defines = new Defines();
		defaults = new Defaults();
		storages = new Storages();
	}
	
	public void processTargetSelection(HierarchicalConfiguration<ImmutableNode> node, String[] targets) throws Exception {
		for (int i = 0; i < targets.length; i++) {
			List<HierarchicalConfiguration<ImmutableNode>> targetNodes = node.configurationsAt("target[name='"+targets[i]+"']");
   			processTargets(targetNodes);
    	}
	}
    
	public void processAllTargets(HierarchicalConfiguration<ImmutableNode> node) throws Exception {
	    List<HierarchicalConfiguration<ImmutableNode>> targetNodes = node.configurationsAt("target");
   		processTargets(targetNodes);
	}
	
	private void processTargets(List<HierarchicalConfiguration<ImmutableNode>> targetNodes) throws Exception {
    	for(HierarchicalConfiguration<ImmutableNode> target : targetNodes)
    	{
			String targetName = target.getString("[@name]");
			log.info("Processing target {}", targetName);
			
			defines.add(target);
			defaults.add(target);
	    	storages.add(target, path);
	   		medias.add(target, path);
			
			new GameBuilder(medias.mediaList, storages, defines.values, defaults.values, path);
			log.info("End of processing target {}", target.getString("[@name]"));
    	}
	}
}
