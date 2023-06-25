package com.widedot.m6809.gamebuilder.configuration.media;

import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.lwtools.LwAssembler;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class LwAsm {
	
	public String format;
	
	public List<Resource> ressources = new ArrayList<Resource>();
	
	public LwAsm(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		
		format = node.getString("[@format]", LwAssembler.RAW);
		
		log.debug("format: {}", format);
		
		Group.recurse(node, path, ressources);
	}
}
