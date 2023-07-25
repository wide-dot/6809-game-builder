package com.widedot.m6809.gamebuilder.plugin.direntry;

import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Settings;
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
import com.widedot.m6809.util.zx0.Compressor;
import com.widedot.m6809.util.zx0.Optimizer;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	
	public static final String ZX0 = "zx0";
	
	public static void run(ImmutableNode node, String path, Defaults defaults, Defines defines, MediaDataInterface media) throws Exception {
    	
		log.debug("Processing direntry ...");
		
		String name = Attribute.getString(node, defaults, "name", "direntry.name");
		String section = Attribute.getString(node, defaults, "section", "direntry.section");
		String codec = Attribute.getStringOpt(node, defaults, "codec", "direntry.codec");
		String loadtimelink = Attribute.getStringOpt(node, defaults, "loadtimelink", "direntry.loadtimelink");
		int maxsize = Attribute.getInteger(node, defaults, "maxsize", "directory.maxsize", Integer.MAX_VALUE);
		String gensymbols = Attribute.getStringOpt(node, defaults, "gensymbols", "direntry.gensymbols");
		
		// generate symbols file
		// ... TODO
		
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
		
		// apply codec
		boolean compress = false;
		if (codec != null && bin.length > 0) {
			if (codec.equals(ZX0)) {
				
				log.debug("Compress data with zx0");
				
				byte[] cbin = null;
				int[] delta = { 0 };
				
				cbin = new Compressor().compress(new Optimizer().optimize(bin, 0, maxsize, 4, false), bin, 0, false, false, delta);
				log.debug("Original size: {}, Packed size: {}, Delta: {}", bin.length, cbin.length, delta[0]);
				
				// automatic selection of compressed or uncompressed data
				if (bin.length > cbin.length) {
					bin = cbin;
					compress = true;
				} else if (delta[0] > Integer.parseInt(Settings.values.get("zx0.maxdelta"))) {
					log.warn("Skip compression: delta ({}) is too high.", delta[0]);
				} else {
					log.warn("Skip compression: compressed data size is bigger or equal to original size.");
				}
			}
		}

		// write to media
	    media.write(section, bin);
	    
	    // generate direntry
	    // compress ?
	    // loadtimelink ?
	    //media.addEntry(...);
		
		log.debug("End of processing direntry");
	}
	
}
