package com.widedot.toolbox.text.txt2bas.impl;

import java.io.File;
import java.util.HashMap;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.toolbox.text.txt2bas.Binary;
import com.widedot.toolbox.text.txt2bas.Txt2BasPlugin;
import com.widedot.toolbox.text.txt2bas.FileResourcesUtils;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class ObjectImpl implements ObjectPluginInterface {

  @Override
  public ObjectDataInterface getObject(ImmutableNode node, String path, Defaults defaults, Defines defines) throws Exception {
	  
	  //read input xml
	  String filename = Attribute.getString(node, defaults, "filename", "txt2bas.filename");
	  String tokenset = Attribute.getString(node, defaults, "tokenset", "txt2bas.tokenset", "to");

	  if (filename == null || filename.equals("")) {
		  String m = "no filename provided for txt2bas!";
		  log.error(m);
		  throw new Exception(m);
	  }
	  
	  File file = new File(path + File.separator + filename);
	  HashMap<byte[], byte[]> tokenmap = FileResourcesUtils.getHashMap(tokenset+".def");
	  Binary bin = new Binary();
	  bin.bytes = Txt2BasPlugin.getBasic(file, tokenmap);
	  return bin;
  }
}
