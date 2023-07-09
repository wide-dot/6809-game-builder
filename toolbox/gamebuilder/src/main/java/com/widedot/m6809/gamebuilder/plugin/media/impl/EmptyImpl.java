package com.widedot.m6809.gamebuilder.plugin.media.impl;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.plugin.lwasm.Converter;
import com.widedot.m6809.gamebuilder.plugin.media.Processor;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.EmptyPluginInterface;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FilePluginInterface;

public class EmptyImpl implements EmptyPluginInterface {

  @Override
  public void run(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
	  
	  Processor.getBin(node, path);
  }
}
