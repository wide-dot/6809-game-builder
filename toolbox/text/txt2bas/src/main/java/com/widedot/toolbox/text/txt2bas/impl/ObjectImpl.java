package com.widedot.toolbox.text.txt2bas.impl;

import java.io.File;
import java.util.HashMap;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.ObjectDataType;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.toolbox.text.txt2bas.Binary;
import com.widedot.toolbox.text.txt2bas.Converter;
import com.widedot.toolbox.text.txt2bas.FileResourcesUtils;

public class ObjectImpl implements ObjectPluginInterface {

  @Override
  public ObjectDataType getObject(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults, Defines defines) throws Exception {
	  
	  //read input xml
	  String filename = node.getString("", null);
	  String tokenset = node.getString("[@tokenset]", "to");;
	  
	  File file = new File(path + File.separator + filename);
	  HashMap<byte[], byte[]> tokenmap = FileResourcesUtils.getHashMap(tokenset+".def");
	  Binary bin = new Binary();
	  bin.bytes = Converter.getBasic(file, tokenmap);
	  return bin;
  }
}
