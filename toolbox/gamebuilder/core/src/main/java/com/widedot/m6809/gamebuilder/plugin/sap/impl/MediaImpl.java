package com.widedot.m6809.gamebuilder.plugin.sap.impl;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.plugin.sap.Processor;
import com.widedot.m6809.gamebuilder.spi.media.MediaDataInterface;
import com.widedot.m6809.gamebuilder.spi.media.MediaPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

public class MediaImpl implements MediaPluginInterface {

  @Override
  public void run(ImmutableNode node, String path, Defaults defaults, Defines defines, MediaDataInterface media) throws Exception {
	  
	  Processor.run(node, path, defaults, defines, media);
  }

}
