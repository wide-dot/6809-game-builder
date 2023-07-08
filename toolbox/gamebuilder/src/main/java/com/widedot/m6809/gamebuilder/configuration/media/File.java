package com.widedot.m6809.gamebuilder.configuration.media;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Iterator;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.configuration.target.Defaults;
import com.widedot.m6809.gamebuilder.directory.FloppyDiskDirectory;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileFactory;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FilePluginInterface;
import com.widedot.m6809.gamebuilder.zx0.Compressor;
import com.widedot.m6809.gamebuilder.zx0.Optimizer;

import lombok.extern.slf4j.Slf4j;
@Slf4j
public class File {
	
	public String name;
	public String section;
	public String block;
	public String codec;
	public int maxsize;
	public byte[] bin;
	public boolean compression = false;
	
	public static final String NO_CODEC = "none";
	public static final String ZX0 = "zx0";
	
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
   		List<byte[]> binList = new ArrayList<byte[]>();
		Iterator<String> keyIter = node.getKeys();
		String key;
		FileFactory f;
		
		while (keyIter.hasNext()) {
			key = keyIter.next();

			// skip this key if not a node
			String plugin = null;
			String[] names = key.split("\\[");
			if (names[0] == null || names[0].equals("") || names[0].contains(".")) continue;
	        plugin = names[0];
	        
			List<HierarchicalConfiguration<ImmutableNode>> elements = node.configurationsAt(plugin);
			for (HierarchicalConfiguration<ImmutableNode> element : elements) {
				
				// external plugin
			    f = Settings.pluginLoader.getFileProcessorFactory(plugin);
			    if (f == null) {
			    	// embeded plugin
			    	f = Settings.embededPluginLoader.getFileProcessorFactory(plugin);
			        if (f == null) {
			        	throw new Exception("Unknown File processor: " + plugin);   	
			        }
			    }
			    
			    final FilePluginInterface fileProcessor = f.build();
			    log.debug("Running plugin: {}", f.name());
			    bin = fileProcessor.doFileProcessor(element, path);
		        binList.add(bin);
			}
		}
		
		// merge all binaries in one byte array
		int length = 0;
		for (byte[] b : binList) {
			length += b.length;
		}
		
		bin = new byte[length];
		int outpos = 0;
		for (byte[] b : binList) {
			for (int i=0; i< b.length; i++) {
				bin[outpos++] = b[i];
			}
		}
		
		binList.clear();
		
		// compress data
		// TODO could have been a plugin, but need a recursive plugin call system ...
		if (!codec.equals(NO_CODEC) && bin.length > 0) {
			if (codec.equals(ZX0)) {
				log.debug("Compress data with zx0");
				byte[] output = null;
				int[] delta = { 0 };
				output = new Compressor().compress(new Optimizer().optimize(bin, 0, 32640, 4, false), bin, 0, false, false, delta);
				if (bin.length > output.length) {
					bin = output;
					compression = true;
				} else if (delta[0] > FloppyDiskDirectory.DELTA_SIZE) {
					log.warn("Skip compression: delta ({}) is too high", delta[0]);
				} else {
					log.warn("Skip compression: compressed data is bigger or equal");
				}
				log.debug("Original size: {}, Packed size: {}, Delta: {}", bin.length, output.length, delta[0]);
			}
		}
	}
}
