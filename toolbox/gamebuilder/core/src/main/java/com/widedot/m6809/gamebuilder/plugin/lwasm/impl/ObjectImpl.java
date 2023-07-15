package com.widedot.m6809.gamebuilder.plugin.lwasm.impl;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.plugin.lwasm.Processor;
import com.widedot.m6809.gamebuilder.spi.ObjectDataType;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

public class ObjectImpl implements ObjectPluginInterface {

  @Override
  public ObjectDataType getObject(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults, Defines defines) throws Exception {
	  
	  return (ObjectDataType) Processor.getObject(node, path, defaults, defines);
  }
}
