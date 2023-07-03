package com.widedot.m6809.gamebuilder.fileprocessor.bin;

import java.io.File;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.configuration.media.Group;

public class Converter {
	public static byte[] getBin(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		List<File> files = new ArrayList<File>();
		List<byte[]> bins = new ArrayList<byte[]>();
		
		Group.recurse(node, path, files);

		int length = 0;
		for (File file : files) {
			byte[] bin = Files.readAllBytes(file.toPath());
			bins.add(bin);
			length += bin.length;
		}
		
		byte[] finalbin = new byte[length];
		int outpos = 0;
		for (byte[] bin : bins) {
			for (int i=0; i<bin.length; i++) {
				finalbin[outpos++] = bin[i];
			}
		}
		
		return finalbin;
	}
}
