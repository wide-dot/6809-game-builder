package com.widedot.m6809.gamebuilder.configuration.media;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Iterator;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.directory.FloppyDiskDirectory;
import com.widedot.m6809.gamebuilder.spi.FileFactory;
import com.widedot.m6809.gamebuilder.spi.FilePluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.zx0.Compressor;
import com.widedot.m6809.gamebuilder.zx0.Optimizer;

import lombok.extern.slf4j.Slf4j;
@Slf4j
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
