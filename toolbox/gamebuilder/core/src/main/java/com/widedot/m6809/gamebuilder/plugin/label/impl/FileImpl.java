package com.widedot.m6809.gamebuilder.plugin.label.impl;

import java.io.File;
import com.widedot.m6809.gamebuilder.spi.BuildContext;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.plugin.label.LabelPlugin;
import com.widedot.m6809.gamebuilder.spi.FilePluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

public class FileImpl implements FilePluginInterface {

  @Override
  public File getFile(ImmutableNode node, BuildContext ctx) throws Exception {
	  
	  return LabelPlugin.getFile(node, ctx);
  }
}
