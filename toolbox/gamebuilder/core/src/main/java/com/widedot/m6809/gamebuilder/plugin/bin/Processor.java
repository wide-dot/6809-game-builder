package com.widedot.m6809.gamebuilder.plugin.bin;

import java.io.File;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	public static byte[] getBytes(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		
		log.debug("Processing bin ...");
		
		List<File> files = new ArrayList<File>();
		List<byte[]> bins = new ArrayList<byte[]>();
		
		//Group.recurse(node, path, files);

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
		
		log.debug("End of processing bin");
		
		return finalbin;
	}
}
