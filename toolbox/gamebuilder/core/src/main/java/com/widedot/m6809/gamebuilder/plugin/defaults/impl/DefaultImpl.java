package com.widedot.m6809.gamebuilder.plugin.defaults.impl;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.plugin.defaults.DefaultPlugin;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

public class DefaultImpl implements DefaultPluginInterface {

  @Override
  public void run(ImmutableNode node, String path, Defaults defaults, Defines defines) throws Exception {
	  
	  DefaultPlugin.run(node, path, defaults, defines);
  }
}
