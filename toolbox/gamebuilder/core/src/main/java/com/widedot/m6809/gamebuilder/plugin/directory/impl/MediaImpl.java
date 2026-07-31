package com.widedot.m6809.gamebuilder.plugin.directory.impl;

import org.apache.commons.configuration2.tree.ImmutableNode;
import com.widedot.m6809.gamebuilder.spi.BuildContext;

import com.widedot.m6809.gamebuilder.plugin.directory.DirectoryPlugin;
import com.widedot.m6809.gamebuilder.spi.media.MediaDataInterface;
import com.widedot.m6809.gamebuilder.spi.media.MediaPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

public class MediaImpl implements MediaPluginInterface {

  @Override
  public void run(ImmutableNode node, BuildContext ctx, MediaDataInterface media) throws Exception {
	  
	  DirectoryPlugin.run(node, ctx, media);
  }

}
