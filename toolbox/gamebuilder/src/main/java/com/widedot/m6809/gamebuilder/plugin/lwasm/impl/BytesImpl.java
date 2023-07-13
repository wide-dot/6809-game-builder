package com.widedot.m6809.gamebuilder.plugin.lwasm.impl;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.plugin.lwasm.Processor;
import com.widedot.m6809.gamebuilder.spi.BytesPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

public class BytesImpl implements BytesPluginInterface {

  @Override
  public byte[] getBytes(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults, Defines defines) throws Exception {
	  
	  return Processor.getBytes(node, path, defaults, defines);
  }
}
