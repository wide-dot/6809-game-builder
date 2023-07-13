package com.widedot.m6809.gamebuilder.plugin.cksumfd640;

import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.spi.BytesFactory;
import com.widedot.m6809.gamebuilder.spi.BytesPluginInterface;
import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	
	public static byte[] getBytes(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults, Defines defines) throws Exception {
    	
		log.info("Processing cksumfd640 ...");
		
		defines.add(node);
		defaults.add(node);

   		// instanciate plugins
		DefaultFactory defaultFactory;
		BytesFactory bytesFactory;
		
		List<ImmutableNode> root = node.getNodeModel().getNodeHandler().getRootNode().getChildren();
		for (ImmutableNode child : root) {
			String plugin = child.getNodeName();

			// skip non plugins
			if (plugin.equals("default") ||
				plugin.equals("define")) continue;
	        
			List<HierarchicalConfiguration<ImmutableNode>> elements = node.configurationsAt(plugin);
			for (HierarchicalConfiguration<ImmutableNode> element : elements) {
				
				// external plugin
				defaultFactory = Settings.pluginLoader.getDefaultFactory(plugin);
			    if (defaultFactory == null) {
			    	// embeded plugin
			    	defaultFactory = Settings.embededPluginLoader.getDefaultFactory(plugin);
			    }
			    
				// external plugin
			    bytesFactory = Settings.pluginLoader.getBytesFactory(plugin);
			    if (bytesFactory == null) {
			    	// embeded plugin
			    	bytesFactory = Settings.embededPluginLoader.getBytesFactory(plugin);
			    }
			    
		        if (defaultFactory == null && bytesFactory == null) {
		        	throw new Exception("Unknown File processor: " + plugin);   	
		        }
			    
		        if (defaultFactory != null) {
				    final DefaultPluginInterface processor = defaultFactory.build();
				    log.debug("Running plugin: {}", defaultFactory.name());
				    processor.run(element, path, defaults, defines);
		        }
		        
		        if (bytesFactory != null) {
				    final BytesPluginInterface processor = bytesFactory.build();
				    log.debug("Running plugin: {}", bytesFactory.name());
				    processor.getBytes(element, path, defaults, defines);
		        }
			}
    	}
		log.info("End of processing cksumfd640");
		return null;
	}

}
