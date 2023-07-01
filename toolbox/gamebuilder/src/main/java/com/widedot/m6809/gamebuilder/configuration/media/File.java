package com.widedot.m6809.gamebuilder.configuration.media;

import java.lang.reflect.Constructor;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.configuration.target.Defaults;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileProcessor;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileProcessorFactory;

import lombok.extern.slf4j.Slf4j;
@Slf4j
public class File {
	
	public String name;
	public String section;
	public String block;
	public String codec;
	public int maxsize;
	public List<byte[]> binList;
	
	public static final String NO_CODEC = "none";
	
	public File(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults) throws Exception {
		
		// load attributes
   		name = node.getString("[@name]", null);
   		codec = node.getString("[@codec]", NO_CODEC);
   		section = node.getString("[@section]", null);
   		block = node.getString("[@block]", null);
   		maxsize = node.getInteger("[@maxsize]", defaults.getInteger("file[@maxsize]"));
   		
   		log.debug("name: {} \t codec: {} \t section: {} \t block: {} \t max size: {}", name, codec, section, block, maxsize);
   		
   		// controls 		
   		if (section == null && block == null) {
   			throw new Exception("section or block is missing for file");
   		}
   		if (section != null && block != null) {
   			throw new Exception("cannot have section and block at the same time for file");
   		}
   		
   		// instanciate each plugins
   		binList = new ArrayList<byte[]>();
		Iterator<String> keyIter = node.getKeys();
		String key;
		byte[] bin;
		FileProcessorFactory f;
		
		while (keyIter.hasNext()) {
			key = keyIter.next();
			
			List<HierarchicalConfiguration<ImmutableNode>> elements = node.configurationsAt(key);
			for (HierarchicalConfiguration<ImmutableNode> element : elements) {
				
				// external plugin
			    f = Settings.pluginLoader.getFileProcessorFactory(key);
			    if (f == null) {
			    	// embeded plugin
			    	f = Settings.embededPluginLoader.getFileProcessorFactory(key);
			        if (f == null) {
			        	throw new Exception("Unknown File processor: " + key);   	
			        }
			    }
			    
			    final FileProcessor fileProcessor = f.build();
			    bin = fileProcessor.doFileProcessor(element, path);
		        binList.add(bin);
			}
		}
	}
}
