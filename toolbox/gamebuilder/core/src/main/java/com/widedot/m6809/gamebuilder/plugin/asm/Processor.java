package com.widedot.m6809.gamebuilder.plugin.asm;

import java.io.File;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	public static File getFile(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
	
		log.debug("Processing asm ...");
		
		String filename = node.getString("[@filename]", null);
		if (filename == null) {
			String s = "Missing filename attribute for asm plugin !";
			log.error(s);
			throw new Exception(s);
		}
		
		filename = path + File.separator + filename;
		File file = new File(filename);
		if (!file.exists()) {
			String s = "file: "+filename+" does not exists !";
			log.error(s);
			throw new Exception(s);			
		}
		
		log.debug("End of processing asm");
		
		return file;
	}
}
