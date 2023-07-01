package com.widedot.m6809.gamebuilder.fileprocessor.lwasm.plugin;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileProcessor;
import com.widedot.m6809.gamebuilder.fileprocessor.bin.Converter;

public class FileProcessorImpl implements FileProcessor {

  @Override
  public byte[] doFileProcessor(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
	  
	  return Converter.getBin(node, path);
  }
}
