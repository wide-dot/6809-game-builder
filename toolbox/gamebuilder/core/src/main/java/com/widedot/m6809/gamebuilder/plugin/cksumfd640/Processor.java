package com.widedot.m6809.gamebuilder.plugin.cksumfd640;

import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.ObjectFactory;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	
	public static Object getObject(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults, Defines defines) throws Exception {
    	
		log.debug("Processing cksumfd640 ...");
		ObjectDataInterface obj = null;
		
		defines.add(node);
		defaults.add(node);

   		// instanciate plugins
		DefaultFactory defaultFactory;
		ObjectFactory objectFactory;
		
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
			    objectFactory = Settings.pluginLoader.getObjectFactory(plugin);
			    if (objectFactory == null) {
			    	// embeded plugin
			    	objectFactory = Settings.embededPluginLoader.getObjectFactory(plugin);
			    }
			    
		        if (defaultFactory == null && objectFactory == null) {
		        	throw new Exception("Unknown Plugin: " + plugin);   	
		        }
			    
		        if (defaultFactory != null) {
				    final DefaultPluginInterface processor = defaultFactory.build();
				    log.debug("Running plugin: {}", defaultFactory.name());
				    processor.run(element, path, defaults, defines);
		        }
		        
		        if (objectFactory != null) {
				    final ObjectPluginInterface processor = objectFactory.build();
				    log.debug("Running plugin: {}", objectFactory.name());
				    obj = processor.getObject(element, path, defaults, defines);
				    
				    checksum(obj.getBytes());
		        }
			}
    	}
		log.debug("End of processing cksumfd640");
		return obj;
	}
	
	public static void checksum(byte[] data) {

		int i=0;
		
		// Initialisation de la somme de controle
		data[127] = (byte) 0x55;

		for (i = 0; i < data.length && i < 120; i++) {
			// Ajout de l'octet courant (sans complément 2) à la somme de contrôle
			data[127] = (byte) (data[127] + data[i]);

			// Encodage de l'octet par complément à 2
			data[i] = (byte) (256 - data[i]);
		}

		for (i = 120; i <= 125; i++) {
			// Ajout de la signature BASIC2 (avec complément à 2) à la somme de contrôle
			data[127] = (byte) (data[127] + (256 - data[i]));
		}
		
	}
}
