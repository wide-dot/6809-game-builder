package com.widedot.toolbox.text.txt2bas.plugin;

import java.io.File;
import java.util.HashMap;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileProcessor;
import com.widedot.toolbox.text.txt2bas.Converter;
import com.widedot.toolbox.text.txt2bas.FileResourcesUtils;

public class FileProcessorImpl implements FileProcessor {

  @Override
  public byte[] doFileProcessor(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
	  
	  //read input xml
	  String filename = node.getString("", null);
	  String tokenset = node.getString("[@tokenset]", "to");;
	  
	  File file = new File(path + File.separator + filename);
	  HashMap<byte[], byte[]> tokenmap = FileResourcesUtils.getHashMap(tokenset+".def");
	  
	  return Converter.getBasic(file, tokenmap);
  }
}
