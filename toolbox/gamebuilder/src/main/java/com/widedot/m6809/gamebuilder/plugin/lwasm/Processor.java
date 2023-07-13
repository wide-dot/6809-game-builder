package com.widedot.m6809.gamebuilder.plugin.lwasm;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.configuration.media.Group;
import com.widedot.m6809.gamebuilder.lwtools.LwAssembler;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	public static byte[] getBytes(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults, Defines defines) throws Exception {
		
		String format = node.getString("[@format]", LwAssembler.RAW);
		log.debug("format: {}", format);
		
		defines.add(node);
		defaults.add(node);
		
		List<byte[]> bins = new ArrayList<byte[]>();
		List<File> files = new ArrayList<File>();
		Group.recurse(node, path, files);
		
		// assemble ressources
		int length = 0;
		for (File file : files) {
			
			// c'est l'assembleur qui doit appeller la routine adhoc en fonction du build format en entrée
			// il doit en ressortir un bin pas un obj ...
			byte[] bin = LwAssembler.assemble(file.getAbsolutePath(), path, defines.values, format);
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
