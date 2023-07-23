package com.widedot.m6809.gamebuilder.plugin.floppydisk;

import java.util.List;

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
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	
	public static void run(ImmutableNode node, String path, Defaults defaults, Defines defines) throws Exception {
    	
		log.debug("Processing floppydisk ...");
		
		String model = Attribute.getString(node, defaults, "model", "floppydisk.model");
		String storageFilename = Attribute.getString(node, defaults, "storage", "floppydisk.storage");
		storageFilename = path + storageFilename;
		
		// load storage definitions from external file
		Storages storages = new Storages(storageFilename);
		Storage storage = storages.get(model);
    	
		// Instanciate the floppy disk image
		FdUtil mediaData = new FdUtil(storage);
		
   		// instanciate plugins
		DefaultFactory defaultFactory;
		MediaFactory mediaFactory;
		
		List<ImmutableNode> root = node.getChildren();
		for (ImmutableNode child : root) {
			String plugin = child.getNodeName();

			// non plugins
			if (plugin.equals("section")) {	
	    		Section section = new Section(child, defaults);
	    		storage.sections.put(section.name, section);
	    		continue;
	    	}
	    	
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
			    processor.run(child, path, defaults, defines);
	        }
	        
	        if (mediaFactory != null) {
			    final MediaPluginInterface processor = mediaFactory.build();
			    log.debug("Running plugin: {}", mediaFactory.name());
			    processor.run(child, path, defaults, defines, mediaData);
	        }
    	}
		
		log.debug("End of processing floppydisk");
	}
}
