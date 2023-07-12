package com.widedot.m6809.gamebuilder.plugin.floppydisk;

import java.util.Iterator;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Section;
import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Storage;
import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Storages;
import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.FileFactory;
import com.widedot.m6809.gamebuilder.spi.FilePluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	
	public static void run(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults, Defines defines) throws Exception {
    	
		log.info("Processing floppydisk ...");
		
		String model = node.getString("[@model]", defaults.getString("floppydisk.model", null));
		if (model == null) {
			throw new Exception("model is missing for floppydisk");
		}
		
		String storageFilename = node.getString("[@storage]", defaults.getString("floppydisk.storage", null));
		if (storageFilename == null) {
			throw new Exception("storage is missing for floppydisk");
		}
		storageFilename = path + storageFilename;
		
		// load storage definitions from external file
		Storages storages = new Storages(storageFilename);
		Storage storage = storages.get(model);
    	
		// load custom storage sections inside floppydisk
	    List<HierarchicalConfiguration<ImmutableNode>> sectionNodes = node.configurationsAt("section");
    	for(HierarchicalConfiguration<ImmutableNode> sectionNode : sectionNodes)
    	{	
    		Section section = new Section(sectionNode);
    		storage.sections.put(section.name, section);
    	}
		
		defines.add(node);
		defaults.add(node);

		//mediaData = new FdUtil(storage.faces, storage.tracks, storage.sectors, storage.sectorSize);
		//sectionIndexes = new HashMap<String, Section>();
		
   		// instanciate plugins
		DefaultFactory defaultFactory;
		FileFactory fileFactory;
		
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
			    fileFactory = Settings.pluginLoader.getFileFactory(plugin);
			    if (fileFactory == null) {
			    	// embeded plugin
			    	fileFactory = Settings.embededPluginLoader.getFileFactory(plugin);
			    }
			    
		        if (defaultFactory == null && fileFactory == null) {
		        	throw new Exception("Unknown File processor: " + plugin);   	
		        }
			    
		        if (defaultFactory != null) {
				    final DefaultPluginInterface processor = defaultFactory.build();
				    log.debug("Running plugin: {}", defaultFactory.name());
				    processor.run(element, path, defaults, defines);
		        }
		        
		        if (fileFactory != null) {
				    final FilePluginInterface processor = fileFactory.build();
				    log.debug("Running plugin: {}", fileFactory.name());
				    processor.run(element, path, defaults, defines);
		        }
			}
    	}
		log.info("End of processing floppydisk");
	}

	public static void add(String sectionName, byte[] data) throws Exception {
		
	}
}
