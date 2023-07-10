package com.widedot.m6809.gamebuilder.configuration.target;

import java.util.Iterator;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.spi.EmptyFactory;
import com.widedot.m6809.gamebuilder.spi.EmptyPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Target {
	
	public String path;
	public Defaults defaults;
	public Defines defines;
	
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
		
		defaults = new Defaults();
		defines = new Defines();
		
    	for(HierarchicalConfiguration<ImmutableNode> node : targetNodes)
    	{
			String targetName = node.getString("[@name]");
			log.info("Processing target {}", targetName);

			defaults.add(node);
			defines.add(node);

	   		// instanciate plugins
			Iterator<String> keyIter = node.getKeys();
			String key;
			EmptyFactory factory;
			
			while (keyIter.hasNext()) {
				key = keyIter.next();

				// skip non plugins
				String plugin = null;
				String[] names = key.split("\\[");
				if (names[0] == null ||
					names[0].equals("") ||
					names[0].contains(".") ||            // process only first level nodes
					names[0].equals("default") ||
					names[0].equals("define")) continue;
				
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
				    processor.run(element, path, defaults, defines);
				}
			}
			
			log.info("End of processing target {}", node.getString("[@name]"));
    	}
	}
}
