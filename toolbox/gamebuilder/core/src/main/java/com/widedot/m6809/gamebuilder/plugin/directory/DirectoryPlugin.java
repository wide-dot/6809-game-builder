package com.widedot.m6809.gamebuilder.plugin.directory;

import java.io.File;
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
import com.widedot.m6809.gamebuilder.plugin.direntry.util.DirEntryDecoder;
import com.widedot.m6809.gamebuilder.spi.media.DirEntry;
import com.widedot.m6809.gamebuilder.spi.media.MediaDataInterface;
import com.widedot.m6809.gamebuilder.spi.media.MediaFactory;
import com.widedot.m6809.gamebuilder.spi.media.MediaPluginInterface;
import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class DirectoryPlugin {
	
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

		Integer id = Attribute.getInteger(node, defaults, "id", "directory.id");
		String section = Attribute.getString(node, defaults, "section", "directory.section");
		String genbinary = Attribute.getStringOpt(node, defaults, "genbinary", "directory.genbinary");
	    String gensymbols = Attribute.getString(node, defaults, "gensymbols", "direntry.gensymbols");
			
		// generate symbols file
		gensymbols = path + File.separator + gensymbols;
		Files.createDirectories(Paths.get(FileUtil.getDir(gensymbols)));
		FileWriter writer = new FileWriter(gensymbols);

		int direntryId = 0;
		for (ImmutableNode child : node.getChildren()) {
			String plugin = child.getNodeName();
			if (plugin.equals("direntry")) {
				
				String name = Attribute.getString(child, defaults, "name", "direntry.name");
				writer.write(name + " equ " + direntryId + System.lineSeparator());
				
				String codec = Attribute.getStringOpt(child, defaults, "codec", "direntry.codec");
				String linkSection = Attribute.getStringOpt(child, defaults, "loadtimelink", "direntry.linksection");

				direntryId++;
				
				if (codec != null) {
					direntryId++;
				}
				
				if (linkSection != null) {
					direntryId++;
				}
			}
		}
		writer.close();
	    
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
		
		// compute directory size 
		int size = 5;
		for (DirEntry entry : media.getDirEntries()) {
			size += entry.data.length;
		}
		
		// set header data 
		byte[] bin = new byte[size];
		int i = 0;
		bin[i++] = 'I';
		bin[i++] = 'D';
		bin[i++] = 'X';
		bin[i++] = id.byteValue();
		bin[i++] = (byte) (Math.ceil(size/256.0));
		
		// set each direntry data
		for (DirEntry entry : media.getDirEntries()) {
			System.arraycopy(entry.data,0,bin,i,entry.data.length);
			i += entry.data.length;
		}

		// write whole directory to media
		media.write(section, bin);
		
		// write whole directory to debug file
		if (genbinary != null) {
			genbinary = path + File.separator + genbinary;
			Files.createDirectories(Paths.get(FileUtil.getDir(genbinary)));
			Files.write(Paths.get(genbinary), bin);
			
			// write directory entries info to text file
			String textFile = genbinary + ".txt";
			FileWriter textWriter = new FileWriter(textFile);
			textWriter.write("Directory Entries Information" + System.lineSeparator());
			textWriter.write("=============================" + System.lineSeparator());
			textWriter.write("Directory ID: " + id + System.lineSeparator());
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
