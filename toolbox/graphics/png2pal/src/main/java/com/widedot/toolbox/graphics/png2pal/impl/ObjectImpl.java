package com.widedot.toolbox.graphics.png2pal.impl;

import java.io.File;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.toolbox.graphics.png2pal.Binary;
import com.widedot.toolbox.graphics.png2pal.Converter;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class ObjectImpl implements ObjectPluginInterface {

  @Override
  public ObjectDataInterface getObject(ImmutableNode node, String path, Defaults defaults, Defines defines) throws Exception {
	  
	  //read input xml
	  String symbol = Attribute.getStringOpt(node, defaults, "symbol", "png2pal.symbol");
	  String mode = Attribute.getString(node, defaults, "mode", "png2pal.mode", Converter.OBJ);
	  Integer colors = Attribute.getInteger(node, defaults, "colors", "png2pal.colors", 16);
	  Integer offset = Attribute.getInteger(node, defaults, "offset", "png2pal.offset", 1);
	  String profile = Attribute.getString(node, defaults, "profile", "png2pal.profile", "to");
	  String filename = Attribute.getStringOpt(node, defaults, "filename", "png2pal.filename");
	  String gensource = Attribute.getStringOpt(node, defaults, "gensource", "png2pal.gensource");

	  if ((filename == null || filename.equals(""))) {
		  String m = "An input filename should be provided for png2pal!";
		  log.error(m);
		  throw new Exception(m);
	  }
	  
	  if (filename != null) filename = path + File.separator + filename;
	  if (gensource != null) gensource = path + File.separator + gensource;
	  
	  Binary bin = new Binary();
	  bin.bytes = Converter.run(symbol, mode, colors, offset, profile, filename, gensource);
	  return bin;
  }
}
