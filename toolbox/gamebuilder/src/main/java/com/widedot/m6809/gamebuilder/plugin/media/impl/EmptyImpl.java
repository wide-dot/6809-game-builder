package com.widedot.m6809.gamebuilder.plugin.media.impl;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.plugin.lwasm.Converter;
import com.widedot.m6809.gamebuilder.plugin.media.Processor;
import com.widedot.m6809.gamebuilder.spi.EmptyPluginInterface;
import com.widedot.m6809.gamebuilder.spi.FilePluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

public class EmptyImpl implements EmptyPluginInterface {

  @Override
  public void run(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults, Defines defines) throws Exception {
	  
	  Processor.run(node, path, defaults, defines);
  }
}
