package com.widedot.m6809.gamebuilder.plugin.media;

import java.util.Iterator;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.configuration.storage.Storage;
import com.widedot.m6809.gamebuilder.configuration.storage.StorageConfiguration;
import com.widedot.m6809.gamebuilder.spi.EmptyFactory;
import com.widedot.m6809.gamebuilder.spi.EmptyPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	
	public static void run(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults, Defines defines) throws Exception {
    	
		log.info("Processing media ...");
		
		String storageName = node.getString("[@storage]", defaults.getString("media.storage", null));
		if (storageName == null) {
			throw new Exception("storage is missing for media");
		}
		
		String include = node.getString("[@include]", defaults.getString("media.include", null));
		if (include == null) {
			throw new Exception("include is missing for media");
		}
		include = path + include;
		
		
		StorageConfiguration storages = new StorageConfiguration(include);
		Storage storage = storages.get(storageName);
		//mediaData = new FdUtil(storage.faces, storage.tracks, storage.sectors, storage.sectorSize);
		//sectionIndexes = new HashMap<String, Section>();
    	
		defines.add(node);
		defaults.add(node);

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
				
				// tester ici plusieurs types de plugin ...
				
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
			
			log.info("End of processing target {}", node.getString("[@name]"));
    	}
    	
    	
    	
	}

}
