package com.widedot.m6809.gamebuilder.plugin.asm;

import java.io.File;
import java.nio.charset.StandardCharsets;

import org.apache.commons.configuration2.tree.ImmutableNode;
import org.apache.commons.io.FileUtils;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class AsmPlugin {
	public static File getFile(ImmutableNode node, BuildContext ctx) throws Exception {
	
		log.debug("Processing asm ...");
		
		File file = null;
		String filename = null;
		String content = (String) node.getValue();
		
		if (content != null) {
			filename = ctx.path + File.separator + ctx.settings.get("generate.unnamedFiles.dir") + File.separator + String.valueOf(java.lang.System.nanoTime()) + ".asm";
			file = new File(filename);
			FileUtils.write(file, content, StandardCharsets.UTF_8, false);
		} else {
			filename = ctx.path + File.separator + Attribute.getString(node, ctx, "filename");
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
