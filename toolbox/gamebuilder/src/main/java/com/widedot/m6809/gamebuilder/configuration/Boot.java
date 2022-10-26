package com.widedot.m6809.gamebuilder.configuration;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

public class Boot {
	
	public FileSet fileset;
	
	public Boot(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		fileset = new FileSet(node, path);
	}
}
