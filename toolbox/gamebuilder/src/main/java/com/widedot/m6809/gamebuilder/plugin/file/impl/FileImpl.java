package com.widedot.m6809.gamebuilder.plugin.file.impl;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.plugin.bin.Converter;
import com.widedot.m6809.gamebuilder.spi.FilePluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

public class FileImpl implements FilePluginInterface {

  @Override
  public byte[] run(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults, Defines defines) throws Exception {
	  
	  return Converter.getBin(node, path);
  }
}
