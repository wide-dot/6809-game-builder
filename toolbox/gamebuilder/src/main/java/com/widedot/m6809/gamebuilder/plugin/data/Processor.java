package com.widedot.m6809.gamebuilder.plugin.data;

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
	
	public static byte[] run(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults, Defines defines) throws Exception {
    	
		log.debug("Processing data ...");
		
		String section = node.getString("[@section]",  defaults.getString("data.section", null));
		int maxsize = Integer.decode(node.getString("[@maxsize]", defaults.getString("data.maxsize", String.valueOf(Integer.MAX_VALUE))));
   		
   		log.debug("section: {} \t max size: {}", section, maxsize);
   		
		//mediaData = new FdUtil(storage.faces, storage.tracks, storage.sectors, storage.sectorSize);
		//sectionIndexes = new HashMap<String, Section>();
    	
		defines.add(node);
		defaults.add(node);

   		// instanciate plugins
		DefaultFactory emptyfactory;
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
				emptyfactory = Settings.pluginLoader.getDefaultFactory(plugin);
			    if (emptyfactory == null) {
			    	// embeded plugin
			    	emptyfactory = Settings.embededPluginLoader.getDefaultFactory(plugin);
			    }
			    
				// external plugin
			    bytesFactory = Settings.pluginLoader.getBytesFactory(plugin);
			    if (bytesFactory == null) {
			    	// embeded plugin
			    	bytesFactory = Settings.embededPluginLoader.getBytesFactory(plugin);
			    }
			    
		        if (emptyfactory == null && bytesFactory == null) {
		        	throw new Exception("Unknown File processor: " + plugin);   	
		        }
			    
		        if (emptyfactory != null) {
				    final DefaultPluginInterface processor = emptyfactory.build();
				    log.debug("Running plugin: {}", emptyfactory.name());
				    processor.run(element, path, defaults, defines);
		        }
		        
		        if (bytesFactory != null) {
				    final BytesPluginInterface processor = bytesFactory.build();
				    log.debug("Running plugin: {}", bytesFactory.name());
				    processor.getBytes(element, path, defaults, defines);
		        }
			}
    	}
		log.debug("End of processing data");
		return null;
	}

}
