package com.widedot.m6809.gamebuilder.plugin.directory;

import java.io.File;
import com.widedot.m6809.gamebuilder.spi.BuildContext;
import java.io.FileWriter;
import java.nio.file.Files;
import java.nio.file.Paths;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.pluginloader.Plugins;
import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.m6809.gamebuilder.spi.globals.FileIds;
import com.widedot.m6809.gamebuilder.plugin.direntry.DirEntryPlugin;
import com.widedot.m6809.gamebuilder.plugin.direntry.util.DirEntryDecoder;
import com.widedot.m6809.gamebuilder.spi.media.DirEntry;
import com.widedot.m6809.gamebuilder.spi.media.MediaDataInterface;
import com.widedot.m6809.gamebuilder.spi.media.MediaFactory;
import com.widedot.m6809.gamebuilder.spi.media.MediaPluginInterface;
import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class DirectoryPlugin {
	
//	Directory Header (7 bytes)
//  -----------------------------------------------------------------------------------------------
//	[I] [D] [X] : [tag]
//	[0000 0000] : [disk id 0-255]
//	[0000 0000] : [nb of sectors to load for this index]
//	[0000 0000] [0000 0000] : [global file id of the first entry of this directory]
//	                          file ids are allocated continuously across all the
//	                          directories of a target, so that a file is identified
//	                          by its id alone at runtime ; the loader subtracts this
//	                          base to get the entry index inside this directory
	
//	Directory content
//  -----------------------------------------------------------------------------------------------
//  ...         : direntries

	
	public static void run(ImmutableNode node, BuildContext ctx, MediaDataInterface media) throws Exception {
    	
		log.debug("Processing directory ...");

		Integer id = Attribute.getInteger(node, ctx.defaults, "id", "directory.id");
		String section = Attribute.getString(node, ctx.defaults, "section", "directory.section");
		String genbinary = Attribute.getStringOpt(node, ctx.defaults, "genbinary", "directory.genbinary");
	    String gensymbols = Attribute.getString(node, ctx.defaults, "gensymbols", "direntry.gensymbols");
			
		// generate symbols file
		gensymbols = ctx.path + File.separator + gensymbols;
		Files.createDirectories(Paths.get(FileUtil.getDir(gensymbols)));
		FileWriter writer = new FileWriter(gensymbols);

		// file ids are global to the target : keep numbering where the
		// previous directory left off, and record the base in the header
		int baseId = ctx.fileIds.peek();
		int direntryId = baseId;
		for (ImmutableNode child : node.getChildren()) {
			String plugin = child.getNodeName();
			if (plugin.equals("direntry")) {
				
				String name = Attribute.getString(child, ctx.defaults, "name", "direntry.name");
				writer.write(name + " equ " + direntryId + System.lineSeparator());
				
				String codec = Attribute.getStringOpt(child, ctx.defaults, "codec", "direntry.codec");
				String linkSection = Attribute.getStringOpt(child, ctx.defaults, "loadtimelink", "direntry.linksection");

				direntryId += DirEntryPlugin.blockCount(codec, linkSection);
			}
		}
		writer.close();
		ctx.fileIds.next = direntryId;
		log.debug("directory {} : file ids {} to {}", id, baseId, direntryId-1);
	    
   		// instanciate plugins
		DefaultFactory defaultFactory;
		MediaFactory mediaFactory;
		
		// instanciate local definitions
		// nested containers get their own defaults and defines
		BuildContext localCtx = ctx.child();

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
			    processor.run(child, localCtx);
				ctx.publish(localCtx);
	        }
	        
	        if (mediaFactory != null) {
			    final MediaPluginInterface processor = mediaFactory.build();
			    log.debug("Running plugin: {}", mediaFactory.name());
			    processor.run(child, localCtx, media);
			    ctx.publish(localCtx);
	        }
    	}
		
		// compute directory size 
		int size = 7;
		int emittedBlocks = 0;
		for (DirEntry entry : media.getDirEntries()) {
			size += entry.data.length;
			emittedBlocks += entry.data.length / DirEntryPlugin.BLOCK_SIZE;
		}

		// the ids handed out above are indexes into this very table : if the two
		// ever disagree, every file after the divergence is read at the wrong
		// offset by loader.dir.getFile
		int reservedBlocks = direntryId - baseId;
		if (emittedBlocks != reservedBlocks) {
			throw new Exception("Directory " + id + " emitted " + emittedBlocks
					+ " entry blocks while " + reservedBlocks + " file ids were reserved");
		}
		
		// the header stores the directory length as a sector count on one byte
		int nsector = (int) Math.ceil(size/256.0);
		if (nsector > 255) {
			throw new Exception("Directory holds " + nsector + " sectors, only 255 can be described");
		}

		// set header data 
		byte[] bin = new byte[size];
		int i = 0;
		bin[i++] = 'I';
		bin[i++] = 'D';
		bin[i++] = 'X';
		bin[i++] = id.byteValue();
		bin[i++] = (byte) nsector;
		bin[i++] = (byte) ((baseId >> 8) & 0xff);
		bin[i++] = (byte) (baseId & 0xff);
		
		// set each direntry data
		for (DirEntry entry : media.getDirEntries()) {
			System.arraycopy(entry.data,0,bin,i,entry.data.length);
			i += entry.data.length;
		}

		// write whole directory to media
		media.write(section, bin);
		
		// write whole directory to debug file
		if (genbinary != null) {
			genbinary = ctx.path + File.separator + genbinary;
			Files.createDirectories(Paths.get(FileUtil.getDir(genbinary)));
			Files.write(Paths.get(genbinary), bin);
			
			// write directory entries info to text file
			String textFile = genbinary + ".txt";
			FileWriter textWriter = new FileWriter(textFile);
			textWriter.write("Directory Entries Information" + System.lineSeparator());
			textWriter.write("=============================" + System.lineSeparator());
			textWriter.write("Directory ID: " + id + System.lineSeparator());
			textWriter.write("Base file ID: " + baseId + System.lineSeparator());
			textWriter.write("Directory structure size: " + size + " bytes" + System.lineSeparator());
			textWriter.write("Directory storage - Number of sectors to load: " + (byte) (Math.ceil(size/256.0)) + System.lineSeparator());
			textWriter.write(System.lineSeparator());
			
			int entryIndex = 0;
			for (DirEntry entry : media.getDirEntries()) {
				textWriter.write(System.lineSeparator());
				textWriter.write("=== Entry " + entryIndex + " [" + entry.name + "] ===" + System.lineSeparator());
				textWriter.write(DirEntryDecoder.analyzeEntry(entry));
				textWriter.write(System.lineSeparator());
				entryIndex++;
			}
			textWriter.close();
		}
		
		log.debug("End of processing directory");
	}

}
