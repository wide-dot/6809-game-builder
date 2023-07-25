package com.widedot.m6809.gamebuilder.plugin.data;

import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.pluginloader.Plugins;
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

		// binary data
		List<ObjectDataInterface> objects = new ArrayList<ObjectDataInterface>();
		byte[] bin;
		
   		// instanciate plugins
		DefaultFactory defaultFactory;
		ObjectFactory objectFactory;
		
		// instanciate local definitions
		Defaults localDefaults = new Defaults(defaults.values);
		Defines localDefines = new Defines(defines.values);
		
		for (ImmutableNode child : node.getChildren()) {
			String plugin = child.getNodeName();
		
			defaultFactory = Plugins.getDefaultFactory(plugin);
			objectFactory = Plugins.getObjectFactory(plugin);
		    
	        if (defaultFactory == null && objectFactory == null) {
	        	throw new Exception("Unknown Plugin: " + plugin);   	
	        }
		    
	        if (defaultFactory != null) {
			    final DefaultPluginInterface processor = defaultFactory.build();
			    log.debug("Running plugin: {}", defaultFactory.name());
			    processor.run(child, path, localDefaults, localDefines);
			    defines.publish(localDefines);
	        }
	        
	        if (objectFactory != null) {
			    final ObjectPluginInterface processor = objectFactory.build();
			    log.debug("Running plugin: {}", objectFactory.name());
			    objects.add(processor.getObject(child, path, localDefaults, localDefines));
			    defines.publish(localDefines);
	        }
    	}
		
		// merge all binaries in one byte array
		int length = 0;
		for (ObjectDataInterface obj : objects) {
			length += obj.getBytes().length;
		}
		
	    if (length > maxsize) {
			String m = "data size " + length + " is over maxsize: " + maxsize;
			log.error(m);
			throw new Exception(m);
	    }
		
		bin = new byte[length];
		int o = 0;
		for (ObjectDataInterface obj : objects) {
			byte[] sbin = obj.getBytes();
			for (int i=0; i< sbin.length; i++) {
				bin[o++] = sbin[i];
			}
		}		
		
	    media.write(section, bin);
		
		log.debug("End of processing data");
	}

}
