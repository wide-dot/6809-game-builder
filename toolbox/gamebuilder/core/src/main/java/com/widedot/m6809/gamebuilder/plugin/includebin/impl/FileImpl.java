package com.widedot.m6809.gamebuilder.plugin.includebin.impl;

import java.io.File;
import com.widedot.m6809.gamebuilder.spi.BuildContext;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.plugin.includebin.IncludeBinPlugin;
import com.widedot.m6809.gamebuilder.spi.FilePluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

public class FileImpl implements FilePluginInterface {

  @Override
  public File getFile(ImmutableNode node, BuildContext ctx) throws Exception {
	  
	  return IncludeBinPlugin.getFile(node, ctx);
  }
}
