package com.widedot.m6809.gamebuilder.plugin.lwasm;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;
import org.apache.commons.io.FileUtils;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.LwAssembler;
import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.FileFactory;
import com.widedot.m6809.gamebuilder.spi.FilePluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	public static byte[] getBytes(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults, Defines defines) throws Exception {
		
		log.debug("Processing lwasm ...");
		
		String format = node.getString("[@format]", LwAssembler.RAW);
		log.debug("format: {}", format);
		
		defines.add(node);
		defaults.add(node);
		
		List<File> files = new ArrayList<File>();
		
   		// instanciate plugins
		DefaultFactory defaultFactory;
		FileFactory fileFactory;
		
		List<ImmutableNode> root = node.getNodeModel().getNodeHandler().getRootNode().getChildren();
		for (ImmutableNode child : root) {
			String plugin = child.getNodeName();

			// skip non plugins
			if (plugin.equals("default") ||
				plugin.equals("define")) continue;
			
			List<HierarchicalConfiguration<ImmutableNode>> elements = node.configurationsAt(plugin);
			for (HierarchicalConfiguration<ImmutableNode> element : elements) {
				
				// external plugin
				defaultFactory = Settings.pluginLoader.getDefaultFactory(plugin);
			    if (defaultFactory == null) {
			    	// embeded plugin
			    	defaultFactory = Settings.embededPluginLoader.getDefaultFactory(plugin);
			    }
			    
				// external plugin
			    fileFactory = Settings.pluginLoader.getFileFactory(plugin);
			    if (fileFactory == null) {
			    	// embeded plugin
			    	fileFactory = Settings.embededPluginLoader.getFileFactory(plugin);
			    }
			    
		        if (defaultFactory == null && fileFactory == null) {
		        	throw new Exception("Unknown File processor: " + plugin);   	
		        }
			    
		        if (defaultFactory != null) {
				    final DefaultPluginInterface processor = defaultFactory.build();
				    log.debug("Running plugin: {}", defaultFactory.name());
				    processor.run(element, path, defaults, defines);
		        }
		        
		        if (fileFactory != null) {
				    final FilePluginInterface processor = fileFactory.build();
				    log.debug("Running plugin: {}", fileFactory.name());
				    files.add(processor.getFile(element, path, defaults, defines));
		        }
			}
		}
		
		// concat ressources
		String filename = path + File.separator + Settings.values.get("build.dir") + File.separator + String.valueOf(java.lang.System.nanoTime()) + ".asm";
		File tmpfile = new File(filename);		
		
		for (File file : files) {
			String fileStr = FileUtils.readFileToString(file, StandardCharsets.UTF_8);
			FileUtils.write(tmpfile, fileStr, StandardCharsets.UTF_8, true);
		}
		
		// assemble		
		byte[] out = LwAssembler.assemble(tmpfile.getAbsolutePath(), path, defines.values, format);
		
		log.debug("End of processing lwasm");
		
		return out;
	}
}
