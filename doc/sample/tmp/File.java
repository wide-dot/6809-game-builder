package com.widedot.m6809.gamebuilder.configuration.media;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;

import lombok.extern.slf4j.Slf4j;

public class File {
	
	public String name;
	public String section;
	public String block;
	public String codec;
	public int maxsize;
	public byte[] bin;
	public boolean compression = false;
	
	public static final String NO_CODEC = "none";
	public static final String ZX0 = "zx0";
	
	public File(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults) throws Exception {

	}
}
