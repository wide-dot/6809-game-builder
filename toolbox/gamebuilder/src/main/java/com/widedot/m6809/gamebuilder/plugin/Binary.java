package com.widedot.m6809.gamebuilder.plugin;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

public class Binary {
	
	public byte[] bin;
	
	public Binary(HierarchicalConfiguration<ImmutableNode> node) throws IOException {
		//bin = Files.readAllBytes(Paths.get(filename));
	}	

}
