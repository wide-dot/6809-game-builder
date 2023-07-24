package com.widedot.m6809.gamebuilder.plugin.lwasm;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.tree.ImmutableNode;
import org.apache.commons.io.FileUtils;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.LwAssembler;
import com.widedot.m6809.gamebuilder.pluginloader.Plugins;
import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.FileFactory;
import com.widedot.m6809.gamebuilder.spi.FilePluginInterface;
import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	public static Object getObject(ImmutableNode node, String path, Defaults defaults, Defines defines) throws Exception {
		
		log.debug("Processing lwasm ...");
		
		String format = Attribute.getString(node, defaults, "format", "lwasm.format", LwAssembler.RAW);
		String gensource = Attribute.getStringOpt(node, defaults, "gensource", "lwasm.gensource");
		
		List<File> files = new ArrayList<File>();
		
   		// instanciate plugins
		DefaultFactory defaultFactory;
		FileFactory fileFactory;
		
		// instanciate local definitions
		Defaults localDefaults = new Defaults(defaults.values);
		Defines localDefines = new Defines(defines.values);
				
		for (ImmutableNode child : node.getChildren()) {
			String plugin = child.getNodeName();

			defaultFactory = Plugins.getDefaultFactory(plugin);
			fileFactory = Plugins.getFileFactory(plugin);
		    
	        if (defaultFactory == null && fileFactory == null) {
	        	throw new Exception("Unknown Plugin: " + plugin);   	
	        }
		    
	        if (defaultFactory != null) {
			    final DefaultPluginInterface processor = defaultFactory.build();
			    log.debug("Running plugin: {}", defaultFactory.name());
			    processor.run(child, path, localDefaults, localDefines);
			    defines.publish(localDefines);
	        }
	        
	        if (fileFactory != null) {
			    final FilePluginInterface processor = fileFactory.build();
			    log.debug("Running plugin: {}", fileFactory.name());
			    files.add(processor.getFile(child, path, localDefaults, localDefines));
			    defines.publish(localDefines);
	        }
		}

		// check if at least a file is provided
		if (files.size() == 0) {
			String msg = "no files to process for lwasm!";
			log.error(msg);
			throw new Exception(msg);
		}

		// input file for lwasm
		File asmFile = null;
		String asmFilename = null;
		
		// set default generated source filename if specified
		if (gensource != null) {
			asmFilename = path + File.separator + Settings.values.get("generate.dir") + File.separator + gensource;
			asmFile = concat(files, asmFilename);
			
		} else {
		
			// no specified gensource
			
			if (files.size() == 1 ) {
				// only one file, use original file as source
				asmFile = files.get(0);
			} else {
				// multiple files, use temp file with timestamp name 
				asmFilename = path + File.separator + Settings.values.get("generate.dir") + File.separator + String.valueOf(java.lang.System.nanoTime()) + ".asm";
				asmFile = concat(files, asmFilename);
			}
		}

		// assemble		
		ObjectDataInterface obj = LwAssembler.assemble(asmFile.getAbsolutePath(), path, localDefines, format);
		defines.publish(localDefines);
		log.debug("End of processing lwasm");
		
		return obj;
	}
	
	public static File concat(List<File> files, String asmFilename) throws IOException {
		File asmFile = new File(asmFilename);
		boolean append = false;
		for (File file : files) {
			String fileStr = FileUtils.readFileToString(file, StandardCharsets.UTF_8);
			FileUtils.write(asmFile, fileStr, StandardCharsets.UTF_8, append);
			append = true;
		}	
		return asmFile;
	}
}
