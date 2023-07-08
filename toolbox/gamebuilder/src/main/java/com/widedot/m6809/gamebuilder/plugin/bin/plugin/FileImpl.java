package com.widedot.m6809.gamebuilder.plugin.bin.plugin;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.plugin.bin.Converter;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FilePluginInterface;

public class FileImpl implements FilePluginInterface {

  @Override
  public byte[] doFileProcessor(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
	  
	  return Converter.getBin(node, path);
  }
}
