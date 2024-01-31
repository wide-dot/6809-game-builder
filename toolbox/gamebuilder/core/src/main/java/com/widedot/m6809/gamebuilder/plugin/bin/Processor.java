package com.widedot.m6809.gamebuilder.plugin.bin;

import java.io.File;
import java.nio.file.Files;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	public static ObjectDataInterface getObject(ImmutableNode node, String path) throws Exception {
		
		log.debug("Processing bin ...");
		String filename = path + File.separator + Attribute.getString(node, "filename", "bin.filename");
		File file = new File(filename);
		Binary bin = new Binary();
		bin.bytes = Files.readAllBytes(file.toPath());
		
		log.debug("End of processing bin");
		
		return bin;
	}
}
