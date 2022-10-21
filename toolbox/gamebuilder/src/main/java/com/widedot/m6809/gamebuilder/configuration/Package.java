package com.widedot.m6809.gamebuilder.configuration;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import lombok.extern.slf4j.Slf4j;
@Slf4j
public class Package {
	
	public String catalog;
	public String filename;
	
	public Package(HierarchicalConfiguration<ImmutableNode> node) {
		catalog = node.getString("[@catalog]", null);
		filename = node.getString("", null);
		log.debug("catalog: "+catalog);
		log.debug("package: "+filename);
	}
}
