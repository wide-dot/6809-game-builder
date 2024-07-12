package com.widedot.m6809.gamebuilder.plugin.floppydisk.impl;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.plugin.floppydisk.FloppyDiskPlugin;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

public class DefaultImpl implements DefaultPluginInterface {

  @Override
  public void run(ImmutableNode node, String path, Defaults defaults, Defines defines) throws Exception {
	  
	  FloppyDiskPlugin.run(node, path, defaults, defines);
  }
}
