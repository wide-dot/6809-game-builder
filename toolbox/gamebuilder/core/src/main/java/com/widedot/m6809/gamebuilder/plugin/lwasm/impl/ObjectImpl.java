package com.widedot.m6809.gamebuilder.plugin.lwasm.impl;

import org.apache.commons.configuration2.tree.ImmutableNode;
import com.widedot.m6809.gamebuilder.spi.BuildContext;

import com.widedot.m6809.gamebuilder.plugin.lwasm.LwasmPlugin;
import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

public class ObjectImpl implements ObjectPluginInterface {

  @Override
  public ObjectDataInterface getObject(ImmutableNode node, BuildContext ctx) throws Exception {
	  
	  return (ObjectDataInterface) LwasmPlugin.getObject(node, ctx);
  }
}
