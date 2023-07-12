package com.widedot.m6809.gamebuilder.plugin.cksumfd640.impl;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.plugin.data.Processor;
import com.widedot.m6809.gamebuilder.spi.FilePluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

public class FileImpl implements FilePluginInterface {

  @Override
  public byte[] run(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults, Defines defines) throws Exception {
	  
	  return Processor.run(node, path, defaults, defines);
  }
}
