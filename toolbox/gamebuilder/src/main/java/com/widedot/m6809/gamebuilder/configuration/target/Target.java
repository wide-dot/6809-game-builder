package com.widedot.m6809.gamebuilder.configuration.target;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.configuration.media.Medias;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.EmptyFactory;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.EmptyPluginInterface;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Target {
	
	public String path;
	public Defines defines;
	public Defaults defaults;
	public Medias medias;
	
	public Target(String path) throws Exception {
		this.path = path;
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
		
		defines = new Defines();
		defaults = new Defaults();
		medias = new Medias();
		
    	for(HierarchicalConfiguration<ImmutableNode> node : targetNodes)
    	{
			String targetName = node.getString("[@name]");
			log.info("Processing target {}", targetName);

			defines.add(node);
			defaults.add(node);
	   		medias.add(node, path, defaults);

	   		// instanciate plugins
			Iterator<String> keyIter = node.getKeys();
			String key;
			EmptyFactory factory;
			
			while (keyIter.hasNext()) {
				key = keyIter.next();

				// skip this key if not a node
				String plugin = null;
				String[] names = key.split("\\[");
				if (names[0] == null || names[0].equals("") || names[0].contains(".")) continue;
		        plugin = names[0];
		        
				List<HierarchicalConfiguration<ImmutableNode>> elements = node.configurationsAt(plugin);
				for (HierarchicalConfiguration<ImmutableNode> element : elements) {
					
					// external plugin
				    factory = Settings.pluginLoader.getEmptyFactory(plugin);
				    if (factory == null) {
				    	// embeded plugin
				    	factory = Settings.embededPluginLoader.getEmptyFactory(plugin);
				        if (factory == null) {
				        	throw new Exception("Unknown File processor: " + plugin);   	
				        }
				    }
				    
				    final EmptyPluginInterface processor = factory.build();
				    log.debug("Running plugin: {}", factory.name());
				    processor.run(element, path);
				}
			}
			
			log.info("End of processing target {}", node.getString("[@name]"));
    	}
	}
}
