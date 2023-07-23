package com.widedot.m6809.gamebuilder.spi.configuration;

import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.tree.ImmutableNode;

public class Configurations {
	
	public static List<ImmutableNode> at(ImmutableNode node, String nodeName) throws Exception {
		List<ImmutableNode> nodes = new ArrayList<ImmutableNode>();
		
		List<ImmutableNode> root = node.getChildren();
		for (ImmutableNode child : root) {
			if (child.getNodeName().equals(nodeName)) {
				nodes.add(child);
			}
		}
		
		return nodes;
	}
	
}
