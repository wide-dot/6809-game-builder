package com.widedot.toolbox.text.phoneme.impl;

import java.io.File;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.toolbox.text.phoneme.Binary;
import com.widedot.toolbox.text.phoneme.PhonemePlugin;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class ObjectImpl implements ObjectPluginInterface {

  @Override
  public ObjectDataInterface getObject(ImmutableNode node, String path, Defaults defaults, Defines defines) throws Exception {
	  
	  //read input xml
	  String filename = Attribute.getString(node, defaults, "filename", "phoneme.filename");
	  String lang = Attribute.getString(node, defaults, "tokenset", "phoneme.lang", "fr");

	  if (filename == null || filename.equals("")) {
		  String m = "no filename provided for phoneme!";
		  log.error(m);
		  throw new Exception(m);
	  }
	  
	  File file = new File(path + File.separator + filename);
	  Binary bin = new Binary();
	  bin.bytes = PhonemePlugin.run(file, lang);
	  return bin;
  }
}
