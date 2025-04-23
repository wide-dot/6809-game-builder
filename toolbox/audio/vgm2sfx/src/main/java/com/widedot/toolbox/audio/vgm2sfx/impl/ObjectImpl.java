package com.widedot.toolbox.audio.vgm2sfx.impl;

import java.io.File;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.toolbox.audio.vgm2sfx.Binary;
import com.widedot.toolbox.audio.vgm2sfx.Vgm2SfxPlugin;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class ObjectImpl implements ObjectPluginInterface {

  @Override
  public ObjectDataInterface getObject(ImmutableNode node, String path, Defaults defaults, Defines defines) throws Exception {
	  
	  //read input xml
	  String filename = Attribute.getStringOpt(node, defaults, "filename", "vgm2sfx.filename");
	  String gensource = Attribute.getStringOpt(node, defaults, "gensource", "vgm2sfx.gensource");

	  if ((filename == null || filename.equals(""))) {
		  String m = "An input filename should be provided for vgm2sfx!";
		  log.error(m);
		  throw new Exception(m);
	  }
	  
	  if (filename != null) filename = path + File.separator + filename;
	  if (gensource != null) gensource = path + File.separator + gensource;
	  
	  Binary bin = new Binary();
	  	Vgm2SfxPlugin.filename = filename;
	  	Vgm2SfxPlugin.gensource = gensource; 
		bin.bytes = Vgm2SfxPlugin.run();
	return bin;
  }
}
