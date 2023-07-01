package com.widedot.m6809.gamebuilder.fileprocessor.lwasm;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.configuration.media.Group;
import com.widedot.m6809.gamebuilder.configuration.media.Resource;
import com.widedot.m6809.gamebuilder.lwtools.LwAssembler;
import com.widedot.m6809.gamebuilder.lwtools.format.LwRaw;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Converter {
	public static byte[] getBin(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		
		String format = node.getString("[@format]", LwAssembler.RAW);
		log.debug("format: {}", format);
		
		// parse each define inside defines
		HashMap<String, String> defines = new HashMap<String, String>();
		
	    List<HierarchicalConfiguration<ImmutableNode>> defineNodes = node.configurationsAt("define");
    	for(HierarchicalConfiguration<ImmutableNode> defineNode : defineNodes)
    	{
    		String symbol = defineNode.getString("[@symbol]", null);
    		String value = defineNode.getString("[@value]", null);
    		defines.put(symbol, value);
    		log.debug("define symbol: {} value: {}", symbol, value);
    	} 	
		
		List<Resource> resources = new ArrayList<Resource>();
		List<Object> objects = new ArrayList<Object>();
		Group.recurse(node, path, resources);
		
		// assemble ressources
		int length = 0;
		for (Resource resource : resources) {
			Object object = LwAssembler.assemble(resource.filename, path, defines, format);
			objects.add(object);
			length += ((LwRaw) object).bin.length; // TODO problème ici ... dépend pas du type
			// pourquoi on utilise plus resource ??? pour le bin ???
		}

		// concat binaries
		log.debug("Concat assembled binaries");
		byte[] bin = new byte[length];
		int i = 0;
		for (Resource resource : resources) {
			System.arraycopy(resource.bin, 0, bin, i, resource.bin.length);
			i += resource.bin.length;
		}
		
		
		return bin;
	}
}
