package com.widedot.m6809.gamebuilder.configuration.media;

import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.configuration.target.Defaults;

import lombok.extern.slf4j.Slf4j;
@Slf4j
public class File {
	
	public String name;
	public String section;
	public String block;
	public String codec;
	public int maxsize;
	
	public static final String NO_CODEC = "none";
	
	public File(HierarchicalConfiguration<ImmutableNode> node, Defaults defaults) throws Exception {
   		name = node.getString("[@name]", null);
    		
   		codec = node.getString("[@codec]", NO_CODEC);
   		
   		section = node.getString("[@section]", null);
   		
   		block = node.getString("[block]", null);
   		if (section == null && block == null) {
   			throw new Exception("section or block is missing for group");
   		}
   		if (section != null && block != null) {
   			throw new Exception("cannont declare section and block in a same group");
   		}
   		
   		maxsize = node.getInteger("[@maxsize]", defaults.getInteger("file[@maxsize]"));
    		
   		log.debug("name: {} codec: {} section: {} block: {} max size: {}", name, codec, section, block, maxsize);
   		
   		
   		// lwasm, lwlink, bas, ... TODO
	    List<HierarchicalConfiguration<ImmutableNode>> binFields = node.configurationsAt("bin");
    	for(HierarchicalConfiguration<ImmutableNode> bin : binFields)
    	{
    		
    	}
	}
}
