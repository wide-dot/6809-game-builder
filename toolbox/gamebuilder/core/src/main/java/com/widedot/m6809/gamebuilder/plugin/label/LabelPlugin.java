package com.widedot.m6809.gamebuilder.plugin.label;

import java.io.File;
import java.nio.charset.StandardCharsets;

import org.apache.commons.configuration2.tree.ImmutableNode;
import org.apache.commons.io.FileUtils;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class LabelPlugin {
	public static File getFile(ImmutableNode node, String path, Defaults defaults) throws Exception {
	
		log.debug("Processing label ...");
		
		File file = null;
		String label = Attribute.getString(node, defaults, "name", "label.name");
		
		String content = 	label + " EXPORT" + System.lineSeparator() +
							" SECTION code"   + System.lineSeparator() +
							label             + System.lineSeparator() +
							" ENDSECTION"     + System.lineSeparator();
		String filename = path + File.separator + Settings.values.get("generate.unnamedFiles.dir") + File.separator + String.valueOf(java.lang.System.nanoTime()) + ".asm";
		file = new File(filename);
		FileUtils.write(file, content, StandardCharsets.UTF_8, false);
		
		log.debug("End of processing label");
		
		return file;
	}
}
