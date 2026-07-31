package com.widedot.m6809.gamebuilder;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Target {
	
	private final BuildContext ctx;

	public Target(BuildContext ctx) throws Exception {
		this.ctx = ctx;
	}
	
	public void processTargetSelection(ImmutableNode root, String[] targets) throws Exception {
		log.info("Processing targets: {}", Arrays.toString(targets));
		List<ImmutableNode> nodesToProcess = new ArrayList<ImmutableNode>();
		for (ImmutableNode target : root.getChildren()) {
			if (!"target".equals(target.getNodeName())) {
				continue;
			}
			String name = (String) target.getAttributes().get("name");
			for (int i = 0; i < targets.length; i++) {
				if (targets[i].equals(name)) {
					nodesToProcess.add(target);
				}
			}
		}
		if (nodesToProcess.isEmpty()) {
			throw new Exception("None of the requested targets " + Arrays.toString(targets)
					+ " exists in the configuration file");
		}
		processTargets(nodesToProcess);
	}
    
	public void processAllTargets(ImmutableNode root) throws Exception {
		log.info("Processing all targets in configuration file.");
		List<ImmutableNode> nodesToProcess = new ArrayList<ImmutableNode>();
		for (ImmutableNode target : root.getChildren()) {
			if ("target".equals(target.getNodeName())) {
				nodesToProcess.add(target);
			}
		}
		if (nodesToProcess.isEmpty()) {
			String m = "No target found !";
			log.error(m);
			throw new Exception(m);
		}
   		processTargets(nodesToProcess);
	}
	
	private void processTargets(List<ImmutableNode> targetNodes) throws Exception {
		
    	for(ImmutableNode node : targetNodes)
    	{
			String targetName = (String) node.getAttributes().get("name");
			log.info("Processing target {}", targetName);

			// ids and defines are global to a target : restart them so that two
			// targets of the same game (fd, t2, ...) get identical ids, and so
			// that building "-t fd" alone or "-t sd,fd" yields the same image
			ctx.resetTarget();
			
			for (ImmutableNode child : node.getChildren()) {
				String plugin = child.getNodeName();
			
				DefaultPluginInterface defaultHandler = Handlers.getDefault(plugin);
				ObjectPluginInterface objectHandler = Handlers.getObject(plugin);
			    
		        if (defaultHandler == null && objectHandler == null) {
		        	throw new Exception("Element <" + plugin + "> is not valid here");
		        }
			    
		        if (defaultHandler != null) {
			    log.debug("Running handler: {}", plugin);
				    defaultHandler.run(child, ctx);
		        }
		        
		        if (objectHandler != null) {
			    log.debug("Running handler: {}", plugin);
				    objectHandler.getObject(child, ctx);
		        }
			}
			log.info("End of processing target {}", targetName);
			
    	}
	}
}
