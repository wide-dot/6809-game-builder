package com.widedot.m6809.gamebuilder.fileprocessor.lwasm;

import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.configuration.media.Group;
import com.widedot.m6809.gamebuilder.configuration.media.Resource;

public class Converter {
	public static byte[] getBin(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		List<Resource> resources = new ArrayList<Resource>();
		Group.recurse(node, path, resources);
		
		int length = 0;
		for (Resource resource : resources) {
			length += resource.bin.length;
		}
		
		byte[] bin = new byte[length];
		int outpos = 0;
		for (Resource resource : resources) {
			for (int i=0; i<resource.bin.length; i++) {
				bin[outpos++] = resource.bin[i];
			}
		}
		
		
		
//		// init starting point for writing operations
//		if (!sectionIndexes.containsKey(lwasm.section)) {
//			Section sectionDefinition = storage.sections.get(lwasm.section);
//			Section section = new Section(sectionDefinition);
//			sectionIndexes.put(lwasm.section, section);
//		}
//
//		// assemble ressources
//		int length = 0;
//		for (Ressource ressource : lwasm.ressources) {
//			ressource.computeBin(path, target.defines.values, lwasm.format);
//			length += ressource.bin.length;
//		}
//
//		// concat binaries
//		log.debug("concat binaries");
//		byte[] data = new byte[length];
//		int i = 0;
//		for (Ressource ressource : lwasm.ressources) {
//			System.arraycopy(ressource.bin, 0, data, i, ressource.bin.length);
//			i += ressource.bin.length;
//		}
		
		
		return bin;
	}
}
