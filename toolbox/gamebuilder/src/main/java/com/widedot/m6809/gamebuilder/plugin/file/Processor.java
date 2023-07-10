package com.widedot.m6809.gamebuilder.plugin.file;

import java.util.Iterator;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.configuration.storage.Storage;
import com.widedot.m6809.gamebuilder.configuration.storage.StorageConfiguration;
import com.widedot.m6809.gamebuilder.directory.FloppyDiskDirectory;
import com.widedot.m6809.gamebuilder.spi.EmptyFactory;
import com.widedot.m6809.gamebuilder.spi.EmptyPluginInterface;
import com.widedot.m6809.gamebuilder.spi.FileFactory;
import com.widedot.m6809.gamebuilder.spi.FilePluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.m6809.gamebuilder.zx0.Compressor;
import com.widedot.m6809.gamebuilder.zx0.Optimizer;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	
	public static void run(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults, Defines defines) throws Exception {
    	
		log.info("Processing data ...");
		
		String name = node.getString("[@name]", defaults.getString("data.name", null));
		String section = node.getString("[@section]",  defaults.getString("data.section", null));
		int maxsize = node.getInteger("[@maxsize]", defaults.getInteger("data.maxsize", 0));
   		
   		log.debug("name: {} \t section: {} \t max size: {}", name, section, maxsize);
   		
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
		EmptyFactory emptyfactory;
		FileFactory fileFactory;
		
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
				emptyfactory = Settings.pluginLoader.getEmptyFactory(plugin);
			    if (emptyfactory == null) {
			    	// embeded plugin
			    	emptyfactory = Settings.embededPluginLoader.getEmptyFactory(plugin);
			    }
			    
				// external plugin
			    fileFactory = Settings.pluginLoader.getFileFactory(plugin);
			    if (fileFactory == null) {
			    	// embeded plugin
			    	fileFactory = Settings.embededPluginLoader.getFileFactory(plugin);
			    }
			    
		        if (emptyfactory == null && fileFactory == null) {
		        	throw new Exception("Unknown File processor: " + plugin);   	
		        }
			    
		        if (emptyfactory != null) {
				    final EmptyPluginInterface processor = emptyfactory.build();
				    log.debug("Running plugin: {}", emptyfactory.name());
				    processor.run(element, path, defaults, defines);
		        }
		        
		        if (fileFactory != null) {
				    final FilePluginInterface processor = fileFactory.build();
				    log.debug("Running plugin: {}", fileFactory.name());
				    processor.run(element, path, defaults, defines);
		        }
			}
			
			log.info("End of processing target {}", node.getString("[@name]"));
    	}
	}

}
