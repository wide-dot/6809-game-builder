package com.widedot.m6809.gamebuilder.plugin.data;

import java.util.ArrayList;
import com.widedot.m6809.gamebuilder.Handlers;
import com.widedot.m6809.gamebuilder.spi.BuildContext;
import java.util.List;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.m6809.gamebuilder.spi.media.MediaDataInterface;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class DataPlugin {
	
	public static void run(ImmutableNode node, BuildContext ctx, MediaDataInterface media) throws Exception {
    	
		log.debug("Processing data ...");
		
		String section = Attribute.getString(node, ctx, "section");
		int maxsize = Attribute.getInteger(node, ctx, "maxsize", Integer.MAX_VALUE);

		// binary data
		List<ObjectDataInterface> objects = new ArrayList<ObjectDataInterface>();
		byte[] bin;
		
		// instanciate local definitions
		// nested containers get their own defaults and defines
		BuildContext localCtx = ctx.child();
		
		for (ImmutableNode child : node.getChildren()) {
			String plugin = child.getNodeName();
		
			DefaultPluginInterface defaultHandler = Handlers.getDefault(plugin);
			ObjectPluginInterface objectHandler = Handlers.getObject(plugin);
		    
	        if (defaultHandler == null && objectHandler == null) {
	        	throw new Exception("Element <" + plugin + "> is not valid here");
	        }
		    
	        if (defaultHandler != null) {
			    log.debug("Running handler: {}", plugin);
			    defaultHandler.run(child, localCtx);
			    ctx.publish(localCtx);
	        }
	        
	        if (objectHandler != null) {
			    objects.add(objectHandler.getObject(child, localCtx));
			    ctx.publish(localCtx);
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
