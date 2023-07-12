package com.widedot.m6809.gamebuilder.plugin.floppydisk.impl;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.plugin.floppydisk.Processor;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

public class DefaultImpl implements DefaultPluginInterface {

  @Override
  public void run(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults, Defines defines) throws Exception {
	  
	  Processor.run(node, path, defaults, defines);
  }
}
