package com.widedot.m6809.gamebuilder.plugin.floppydisk;

import org.apache.commons.configuration2.tree.ImmutableNode;
import com.widedot.m6809.gamebuilder.Handlers;
import com.widedot.m6809.gamebuilder.spi.BuildContext;

import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.FdUtil;
import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Section;
import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Storage;
import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Storages;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.media.MediaPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class FloppyDiskPlugin {
	
	public static void run(ImmutableNode node, BuildContext ctx) throws Exception {
    	
		log.debug("Processing floppydisk ...");
		
		String model = Attribute.getString(node, ctx, "model");
		String storageFilename = Attribute.getString(node, ctx, "storage");
		storageFilename = ctx.path + storageFilename;
		
		// load storage definitions from external file
		Storages storages = new Storages(storageFilename);
		Storage storage = storages.get(model);
    	
		// Instanciate the floppy disk image
		FdUtil mediaData = new FdUtil(storage);
		
		// instanciate local definitions
		// nested containers get their own defaults and defines
		BuildContext localCtx = ctx.child();

		for (ImmutableNode child : node.getChildren()) {
			String plugin = child.getNodeName();

			// non plugins
			if (plugin.equals("section")) {	
	    		Section section = new Section(child, ctx.defaults);
	    		storage.sections.put(section.name, section);
	    		continue;
	    	}
	    	
			DefaultPluginInterface defaultHandler = Handlers.getDefault(plugin);
			MediaPluginInterface mediaHandler = Handlers.getMedia(plugin);
		    
	        if (defaultHandler == null && mediaHandler == null) {
	        	throw new Exception("Element <" + plugin + "> is not valid here");
	        }
		    
	        if (defaultHandler != null) {
			    log.debug("Running handler: {}", plugin);
			    defaultHandler.run(child, localCtx);
				ctx.publish(localCtx);
	        }
	        
	        if (mediaHandler != null) {
			    log.debug("Running handler: {}", plugin);
			    mediaHandler.run(child, localCtx, mediaData);
			    ctx.publish(localCtx);
	        }
    	}

		// hand what this disk holds to the occupancy report : its geometry,
		// and every byte range the children wrote, now attributable to an
		// instance. Named after the first image file it produces, so the
		// report speaks the name the user sees in dist/.
		String instance = instanceName(node, ctx, model);
		ctx.occupancy.declareInstance(new com.widedot.m6809.gamebuilder.spi.globals.Occupancy.Instance(
				instance, mediaData.capacity(), storage.segment.faces, storage.segment.tracks,
				storage.segment.sectors, storage.segment.sectorSize));
		for (FdUtil.Piece piece : mediaData.journal()) {
			ctx.occupancy.write(new com.widedot.m6809.gamebuilder.spi.globals.Occupancy.MediaWrite(
					instance, piece.section, piece.start, piece.length, piece.name));
		}

		log.debug("End of processing floppydisk");
	}

	private static String instanceName(ImmutableNode node, BuildContext ctx, String model)
			throws Exception {
		for (ImmutableNode child : node.getChildren()) {
			String name = child.getNodeName();
			if ("fd".equals(name) || "sap".equals(name) || "hfe".equals(name) || "sd".equals(name)) {
				String filename = Attribute.getStringOpt(child, ctx, "filename");
				if (filename != null) {
					int slash = Math.max(filename.lastIndexOf('/'), filename.lastIndexOf('\\'));
					return slash >= 0 ? filename.substring(slash + 1) : filename;
				}
			}
		}
		return model;
	}
}
