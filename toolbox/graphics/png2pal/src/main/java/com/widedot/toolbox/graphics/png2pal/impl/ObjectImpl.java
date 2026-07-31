package com.widedot.toolbox.graphics.png2pal.impl;

import java.io.File;
import com.widedot.m6809.gamebuilder.spi.BuildContext;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.toolbox.graphics.png2pal.Binary;
import com.widedot.toolbox.graphics.png2pal.Png2PalPlugin;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class ObjectImpl implements ObjectPluginInterface {

  @Override
  public ObjectDataInterface getObject(ImmutableNode node, BuildContext ctx) throws Exception {
	  
	  //read input xml
	  String symbol = Attribute.getStringOpt(node, ctx.defaults, "symbol", "png2pal.symbol");
	  String mode = Attribute.getString(node, ctx.defaults, "mode", "png2pal.mode", Png2PalPlugin.OBJ);
	  Integer colors = Attribute.getInteger(node, ctx.defaults, "colors", "png2pal.colors", 16);
	  Integer offset = Attribute.getInteger(node, ctx.defaults, "offset", "png2pal.offset", 1);
	  String profile = Attribute.getString(node, ctx.defaults, "profile", "png2pal.profile", "to");
	  String filename = Attribute.getStringOpt(node, ctx.defaults, "filename", "png2pal.filename");
	  String gensource = Attribute.getStringOpt(node, ctx.defaults, "gensource", "png2pal.gensource");

	  if ((filename == null || filename.equals(""))) {
		  String m = "An input filename should be provided for png2pal!";
		  log.error(m);
		  throw new Exception(m);
	  }
	  
	  if (filename != null) filename = ctx.path + File.separator + filename;
	  if (gensource != null) gensource = ctx.path + File.separator + gensource;
	  
	  Binary bin = new Binary();
	  bin.bytes = Png2PalPlugin.run(symbol, mode, colors, offset, profile, filename, gensource);
	  return bin;
  }
}
