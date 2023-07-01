package com.widedot.m6809.gamebuilder.fileprocessor.bin;

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
		
		return bin;
	}
}
