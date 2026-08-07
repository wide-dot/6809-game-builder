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
		
	    media.write(section, bin, section.toLowerCase());

		// A data block the machine keeps resident (the loader) is the one
		// thing the build both PRODUCES and must draw on the RAM map :
		// declaring its footprint by hand would go stale with every engine
		// change. ram-page/ram-address say where it sits, the reservation
		// takes the MEASURED size. ram-pool reserves a further block right
		// after the code — the TLSF pool is anchored there
		// (loader.memoryPool equ *) — sized by a literal, or by the name of
		// a <define> so the number lives in one place.
		Integer ramPage = Attribute.getIntegerOpt(node, ctx, "ram-page");
		if (ramPage != null) {
			int ramAddress = Attribute.getInteger(node, ctx, "ram-address");
			String name = section.toLowerCase();
			ctx.regions.reserve(new com.widedot.m6809.gamebuilder.spi.globals.Regions.Reserved(
					name, ramPage, ramAddress, bin.length));
			String pool = Attribute.getStringOpt(node, ctx, "ram-pool");
			if (pool != null) {
				int poolSize;
				if (pool.startsWith("fill-to:")) {
					// the pool takes what the code leaves, up to a boundary —
					// the loader's half-page. Mirrors the engine's own default
					// (loader.ADDRESS - loader.memoryPool + $2000) : the code
					// grows, the pool shrinks, the boundary holds.
					int upTo = com.widedot.m6809.gamebuilder.spi.configuration.Values
							.parseInt(pool.substring("fill-to:".length()));
					poolSize = upTo - (ramAddress + bin.length);
					if (poolSize <= 0) {
						throw new Exception("ram-pool: the code (" + bin.length
								+ " bytes) already reaches past the fill-to boundary");
					}
				} else {
					try {
						poolSize = com.widedot.m6809.gamebuilder.spi.configuration.Values.parseInt(pool);
					} catch (Exception notALiteral) {
						String defined = ctx.defines.values.get(pool);
						if (defined == null) {
							throw new Exception("ram-pool: '" + pool + "' is neither a size, a"
									+ " fill-to:<boundary>, nor the name of a <define> declared"
									+ " before this <data>");
						}
						poolSize = com.widedot.m6809.gamebuilder.spi.configuration.Values.parseInt(defined);
					}
				}
				ctx.regions.reserve(new com.widedot.m6809.gamebuilder.spi.globals.Regions.Reserved(
						name + ".pool", ramPage, ramAddress + bin.length, poolSize));
			}
		}

		log.debug("End of processing data");
	}

}
