package com.widedot.m6809.gamebuilder.fileprocessor.lwasm;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.configuration.media.Group;
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
		
		List<byte[]> bins = new ArrayList<byte[]>();
		List<File> files = new ArrayList<File>();
		Group.recurse(node, path, files);
		
		// assemble ressources
		int length = 0;
		for (File file : files) {
			
			// c'est l'assembleur qui doit appeller la routine adhoc en fonction du build format en entrée
			// il doit en ressortir un bin pas un obj ...
			byte[] bin = LwAssembler.assemble(file.getAbsolutePath(), path, defines, format);
			bins.add(bin);
			length += bin.length; // TODO problème ici ... dépend pas du type
			// pourquoi on utilise plus resource ??? pour le bin ???
		}

		// concat binaries mais sans l'objet ressource !
		log.debug("Concat assembled binaries");
		byte[] finalbin = new byte[length];
		int i = 0;
		for (byte[] bin : bins) {
			System.arraycopy(bin, 0, finalbin, i, bin.length);
			i += bin.length;
		}
		
		
		return finalbin;
	}
}
