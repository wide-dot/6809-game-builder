package com.widedot.m6809.gamebuilder.configuration;

import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.lwtools.LwAssembler;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class LwAsm {
	
	public String format;
	public String section;
	public String codec;
	public String symbol;
	public int maxsize;
	
	public List<Ressource> ressources = new ArrayList<Ressource>();
	
	public static final String NO_CODEC = "none";
	
	public LwAsm(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		
		format = node.getString("[@format]", LwAssembler.RAW);
		
		section = node.getString("[@section]", null);
		if (section == null) {
			throw new Exception("section is missing for filegroup");
		}
		
		codec = node.getString("[@codec]", NO_CODEC);
		symbol = node.getString("[@symbol]", null);
		maxsize = node.getInteger("[@maxsize]", -1);
		
		log.debug("format: {} section: {} codec: {} symbol: {} max size: {}", format, section, codec, symbol, maxsize);

		FileGroup.recurse(node, path, ressources);
	}
}
