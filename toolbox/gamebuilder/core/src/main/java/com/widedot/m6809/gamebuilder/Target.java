package com.widedot.m6809.gamebuilder;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.pluginloader.Plugins;
import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
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
		log.info("Processing targets: {}", Arrays.toString(targets));
		List<ImmutableNode> nodesToProcess = new ArrayList<ImmutableNode>(); 
		List<HierarchicalConfiguration<ImmutableNode>> targetNodes = node.configurationsAt("target");
		for(HierarchicalConfiguration<ImmutableNode> target : targetNodes) {
			for (int i = 0; i < targets.length; i++) {
				String name = target.getString("[@name]", null);
				if (name.equals(targets[i])) {
					nodesToProcess.add(target.getNodeModel().getNodeHandler().getRootNode());
				}
			}
		}
		
		processTargets(nodesToProcess);
	}
    
	public void processAllTargets(HierarchicalConfiguration<ImmutableNode> node) throws Exception {
		log.info("Processing all targets in configuration file.");
		List<ImmutableNode> nodesToProcess = new ArrayList<ImmutableNode>(); 
		List<HierarchicalConfiguration<ImmutableNode>> targetNodes = node.configurationsAt("target");
		for(HierarchicalConfiguration<ImmutableNode> target : targetNodes) {
			nodesToProcess.add(target.getNodeModel().getNodeHandler().getRootNode());
		}
		if (nodesToProcess.isEmpty()) {
			String m = "No target found !";
			log.error(m);
			throw new Exception(m);
		}
   		processTargets(nodesToProcess);
	}
	
	private void processTargets(List<ImmutableNode> targetNodes) throws Exception {
		
		defaults = new Defaults();
		defines = new Defines();
		
    	for(ImmutableNode node : targetNodes)
    	{
			String targetName = (String) node.getAttributes().get("name");
			log.info("Processing target {}", targetName);

	   		// instanciate plugins
			DefaultFactory defaultFactory;
			
			for (ImmutableNode child : node.getChildren()) {
				String plugin = child.getNodeName();
			
				// external plugin
				defaultFactory = Plugins.getDefaultFactory(plugin);
			    if (defaultFactory == null) {
			       	throw new Exception("Unknown plugin: " + plugin);   	
			    }
			    
			    final DefaultPluginInterface processor = defaultFactory.build();
			    log.debug("Running plugin: {}", defaultFactory.name());
			    processor.run(child, path, defaults, defines);
			}
			log.info("End of processing target {}", targetName);
			
			// clear target local definitions
			defaults.values.clear();
			defines.values.clear();
    	}
	}
}
