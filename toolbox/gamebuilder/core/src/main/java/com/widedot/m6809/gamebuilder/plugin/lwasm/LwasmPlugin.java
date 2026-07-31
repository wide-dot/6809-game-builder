package com.widedot.m6809.gamebuilder.plugin.lwasm;

import java.io.File;
import com.widedot.m6809.gamebuilder.Handlers;
import com.widedot.m6809.gamebuilder.spi.BuildContext;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.tree.ImmutableNode;
import org.apache.commons.io.FileUtils;

import com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.LwAssembler;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.FilePluginInterface;
import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class LwasmPlugin {
	public static ObjectDataInterface getObject(ImmutableNode node, BuildContext ctx) throws Exception {
		
		log.debug("Processing lwasm ...");
		
		String format = Attribute.getString(node, ctx.defaults, "format", "lwasm.format", LwAssembler.RAW);
		String gensource = Attribute.getStringOpt(node, ctx.defaults, "gensource", "lwasm.gensource");
		String lwasmProcessor = Attribute.getString(node, ctx.defaults, "processor", "lwasm.processor", "6809");
		
		List<File> files = new ArrayList<File>();
		
		// instanciate local definitions
		// nested containers get their own defaults and defines
		BuildContext localCtx = ctx.child();
				
		for (ImmutableNode child : node.getChildren()) {
			String plugin = child.getNodeName();

			DefaultPluginInterface defaultHandler = Handlers.getDefault(plugin);
			FilePluginInterface fileHandler = Handlers.getFile(plugin);
		    
	        if (defaultHandler == null && fileHandler == null) {
	        	throw new Exception("Element <" + plugin + "> is not valid here");
	        }
		    
	        if (defaultHandler != null) {
			    log.debug("Running handler: {}", plugin);
			    defaultHandler.run(child, localCtx);
			    ctx.publish(localCtx);
	        }
	        
	        if (fileHandler != null) {
			    files.add(fileHandler.getFile(child, localCtx));
			    ctx.publish(localCtx);
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
			asmFilename = ctx.path + File.separator + gensource;
			asmFile = concat(files, asmFilename);
			
		} else {
		
			// no specified gensource
			
			if (files.size() == 1 ) {
				// only one file, use original file as source
				asmFile = files.get(0);
			} else {
				// multiple files, use temp file with timestamp name 
				asmFilename = ctx.path + File.separator + ctx.settings.get("generate.unnamedFiles.dir") + File.separator + String.valueOf(java.lang.System.nanoTime()) + ".asm";
				asmFile = concat(files, asmFilename);
			}
		}

		// assemble		
		ObjectDataInterface obj = LwAssembler.assemble(asmFile.getAbsolutePath(), ctx.path, localCtx, format, lwasmProcessor);
		ctx.publish(localCtx);
		log.debug("End of processing lwasm");
		
		return obj;
	}
	
	public static File concat(List<File> files, String asmFilename) throws IOException {
		File asmFile = new File(asmFilename);
		boolean append = false;
		for (File file : files) {
			String fileStr = FileUtils.readFileToString(file, StandardCharsets.UTF_8);
			fileStr += System.lineSeparator();
			FileUtils.write(asmFile, fileStr, StandardCharsets.UTF_8, append);
			append = true;
		}	
		return asmFile;
	}
}
