package com.widedot.m6809.gamebuilder.plugin.floppydisk;

import java.io.File;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.FdUtil;
import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Section;
import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Storage;
import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Storages;
import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.media.MediaFactory;
import com.widedot.m6809.gamebuilder.spi.media.MediaPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	
	public static void run(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults, Defines defines) throws Exception {
    	
		log.debug("Processing floppydisk ...");
		
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

		// Instanciate the floppy disk image
		FdUtil mediaData = new FdUtil(storage);
		
   		// instanciate plugins
		DefaultFactory defaultFactory;
		MediaFactory mediaFactory;
		
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
			    mediaFactory = Settings.pluginLoader.getMediaFactory(plugin);
			    if (mediaFactory == null) {
			    	// embeded plugin
			    	mediaFactory = Settings.embededPluginLoader.getMediaFactory(plugin);
			    }
			    
		        if (defaultFactory == null && mediaFactory == null) {
		        	throw new Exception("Unknown Plugin: " + plugin);   	
		        }
			    
		        if (defaultFactory != null) {
				    final DefaultPluginInterface processor = defaultFactory.build();
				    log.debug("Running plugin: {}", defaultFactory.name());
				    processor.run(element, path, defaults, defines);
		        }
		        
		        if (mediaFactory != null) {
				    final MediaPluginInterface processor = mediaFactory.build();
				    log.debug("Running plugin: {}", mediaFactory.name());
				    processor.run(element, path, defaults, defines, mediaData);
		        }
			}
    	}
		
		mediaData.interleaveData();
		String dirname = path + File.separator + Settings.values.get("dist.dir");
	    File dir = new File(dirname);
	    dir.mkdirs();
		mediaData.save(dirname + File.separator + "disk");
		log.debug("End of processing floppydisk");
	}
}
