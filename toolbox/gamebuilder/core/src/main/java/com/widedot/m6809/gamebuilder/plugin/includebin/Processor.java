package com.widedot.m6809.gamebuilder.plugin.includebin;

import java.io.File;
import java.nio.charset.StandardCharsets;

import org.apache.commons.configuration2.tree.ImmutableNode;
import org.apache.commons.io.FileUtils;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	public static File getFile(ImmutableNode node, String path, Defaults defaults) throws Exception {
	
		log.debug("Processing includebin ...");
		
		File file = null;
		String binFile = Attribute.getString(node, defaults, "filename", "includebin.filename");
		
		String content = 	" SECTION code"  + System.lineSeparator() +
							" INCLUDEBIN \"" + binFile + "\"" + System.lineSeparator() +
							" ENDSECTION"    + System.lineSeparator();
		String filename = path + File.separator + Settings.values.get("generate.unnamedFiles.dir") + File.separator + String.valueOf(java.lang.System.nanoTime()) + ".asm";
		file = new File(filename);
		FileUtils.write(file, content, StandardCharsets.UTF_8, false);
		
		log.debug("End of processing includebin");
		
		return file;
	}
}
