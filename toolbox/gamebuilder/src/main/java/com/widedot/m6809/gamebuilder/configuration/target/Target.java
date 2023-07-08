package com.widedot.m6809.gamebuilder.configuration.target;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.builder.GameBuilder;
import com.widedot.m6809.gamebuilder.configuration.media.Medias;
import com.widedot.m6809.gamebuilder.configuration.storage.Storages;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FilePluginInterface;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FilePluginInterface;

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
	   		List<byte[]> binList = new ArrayList<byte[]>();
			Iterator<String> keyIter = node.getKeys();
			String key;
			FileProcessorFactory f;
			
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
				    f = Settings.pluginLoader.getFileProcessorFactory(plugin);
				    if (f == null) {
				    	// embeded plugin
				    	f = Settings.embededPluginLoader.getFileProcessorFactory(plugin);
				        if (f == null) {
				        	throw new Exception("Unknown File processor: " + plugin);   	
				        }
				    }
				    
				    final FilePluginInterface fileProcessor = f.build();
				    log.debug("Running plugin: {}", f.name());
				    fileProcessor.doFileProcessor(element, path);
				}
			}
			
			log.info("End of processing target {}", node.getString("[@name]"));
    	}
	}
}
