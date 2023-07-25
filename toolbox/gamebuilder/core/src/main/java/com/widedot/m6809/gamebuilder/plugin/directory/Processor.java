package com.widedot.m6809.gamebuilder.plugin.directory;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.pluginloader.Plugins;
import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.m6809.gamebuilder.spi.media.MediaDataInterface;
import com.widedot.m6809.gamebuilder.spi.media.MediaFactory;
import com.widedot.m6809.gamebuilder.spi.media.MediaPluginInterface;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	
//	Directory Header (5 bytes)
//  -----------------------------------------------------------------------------------------------
//	[I] [D] [X] : [tag]
//	[0000 0000] : [disk id 0-255]
//	[0000 0000] : [nb of sectors to load for this index]
	
//	Directory content
//  -----------------------------------------------------------------------------------------------
//  ...         : direntries

	
	public static void run(ImmutableNode node, String path, Defaults defaults, Defines defines, MediaDataInterface media) throws Exception {
    	
		log.debug("Processing directory ...");

		String id = Attribute.getString(node, defaults, "id", "directory.id");
		String section = Attribute.getString(node, defaults, "section", "directory.section");
		String genbinary = Attribute.getStringOpt(node, defaults, "genbinary", "directory.genbinary");
		
   		// instanciate plugins
		DefaultFactory defaultFactory;
		MediaFactory mediaFactory;
		
		// instanciate local definitions
		Defaults localDefaults = new Defaults(defaults.values);
		Defines localDefines = new Defines(defines.values);

		for (ImmutableNode child : node.getChildren()) {
			String plugin = child.getNodeName();
	    	
			defaultFactory = Plugins.getDefaultFactory(plugin);
			mediaFactory = Plugins.getMediaFactory(plugin);
		    
	        if (defaultFactory == null && mediaFactory == null) {
	        	throw new Exception("Unknown Plugin: " + plugin);   	
	        }
		    
	        if (defaultFactory != null) {
			    final DefaultPluginInterface processor = defaultFactory.build();
			    log.debug("Running plugin: {}", defaultFactory.name());
			    processor.run(child, path, localDefaults, localDefines);
				defines.publish(localDefines);
	        }
	        
	        if (mediaFactory != null) {
			    final MediaPluginInterface processor = mediaFactory.build();
			    log.debug("Running plugin: {}", mediaFactory.name());
			    processor.run(child, path, localDefaults, localDefines, media);
			    defines.publish(localDefines);
	        }
    	}
		
		// parse media directory entries
		// ... TODO
		// media.write(section, bin);
	    
		log.debug("End of processing directory");
	}

}
