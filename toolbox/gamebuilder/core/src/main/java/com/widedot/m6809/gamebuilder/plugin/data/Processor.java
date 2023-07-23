package com.widedot.m6809.gamebuilder.plugin.data;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.spi.ObjectFactory;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;
import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.m6809.gamebuilder.spi.media.MediaDataInterface;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	
	public static void run(ImmutableNode node, String path, Defaults defaults, Defines defines, MediaDataInterface media) throws Exception {
    	
		log.debug("Processing data ...");
		
		String section = Attribute.getString(node, defaults, "section", "data.section");
		int maxsize = Attribute.getInteger(node, defaults, "maxsize", "data.maxsize", Integer.MAX_VALUE);

   		// instanciate plugins
		DefaultFactory emptyfactory;
		ObjectFactory objectFactory;
		
		for (ImmutableNode child : node.getChildren()) {
			String plugin = child.getNodeName();
		
			// external plugin
			emptyfactory = Settings.pluginLoader.getDefaultFactory(plugin);
		    if (emptyfactory == null) {
		    	// embeded plugin
		    	emptyfactory = Settings.embededPluginLoader.getDefaultFactory(plugin);
		    }
		    
			// external plugin
		    objectFactory = Settings.pluginLoader.getObjectFactory(plugin);
		    if (objectFactory == null) {
		    	// embeded plugin
		    	objectFactory = Settings.embededPluginLoader.getObjectFactory(plugin);
		    }
		    
	        if (emptyfactory == null && objectFactory == null) {
	        	throw new Exception("Unknown Plugin: " + plugin);   	
	        }
		    
	        if (emptyfactory != null) {
			    final DefaultPluginInterface processor = emptyfactory.build();
			    log.debug("Running plugin: {}", emptyfactory.name());
			    processor.run(child, path, defaults, defines);
	        }
	        
	        if (objectFactory != null) {
			    final ObjectPluginInterface processor = objectFactory.build();
			    log.debug("Running plugin: {}", objectFactory.name());
			    ObjectDataInterface obj = processor.getObject(child, path, defaults, defines);
			    
			    if (obj.getBytes().length > maxsize) {
					String m = "data size is over maxsize: " + obj.getBytes().length;
					log.error(m);
					throw new Exception(m);
			    }
			    media.write(section, obj.getBytes());
	        }
    	}
		log.debug("End of processing data");
	}

}
