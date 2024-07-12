package com.widedot.m6809.gamebuilder.plugin.asm;

import java.io.File;
import java.nio.charset.StandardCharsets;

import org.apache.commons.configuration2.tree.ImmutableNode;
import org.apache.commons.io.FileUtils;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class AsmPlugin {
	public static File getFile(ImmutableNode node, String path, Defaults defaults) throws Exception {
	
		log.debug("Processing asm ...");
		
		File file = null;
		String filename = null;
		String content = (String) node.getValue();
		
		if (content != null) {
			filename = path + File.separator + Settings.values.get("generate.unnamedFiles.dir") + File.separator + String.valueOf(java.lang.System.nanoTime()) + ".asm";
			file = new File(filename);
			FileUtils.write(file, content, StandardCharsets.UTF_8, false);
		} else {
			filename = path + File.separator + Attribute.getString(node, defaults, "filename", "asm.filename");
			file = new File(filename);
			if (!file.exists()) {
				String s = "file: "+filename+" does not exists !";
				log.error(s);
				throw new Exception(s);			
			}
		}
		
		
		log.debug("End of processing asm");
		
		return file;
	}
}
