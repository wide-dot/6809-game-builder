package com.widedot.m6809.gamebuilder.plugin.cksumfd640.impl;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.plugin.cksumfd640.Processor;
import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

public class ObjectImpl implements ObjectPluginInterface {

  @Override
  public ObjectDataInterface getObject(ImmutableNode node, String path, Defaults defaults, Defines defines) throws Exception {
	  
	  return (ObjectDataInterface) Processor.getObject(node, path, defaults, defines);
  }
}
