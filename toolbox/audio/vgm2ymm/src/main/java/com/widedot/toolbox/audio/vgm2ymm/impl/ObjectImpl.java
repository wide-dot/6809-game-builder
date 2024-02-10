package com.widedot.toolbox.audio.vgm2ymm.impl;

import java.io.File;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.toolbox.audio.vgm2ymm.Binary;
import com.widedot.toolbox.audio.vgm2ymm.Converter;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class ObjectImpl implements ObjectPluginInterface {

  @Override
  public ObjectDataInterface getObject(ImmutableNode node, String path, Defaults defaults, Defines defines) throws Exception {
	  
	  //read input xml
	  String filename = Attribute.getStringOpt(node, defaults, "filename", "vgm2ymm.filename");
	  String genbinary = Attribute.getStringOpt(node, defaults, "genbinary", "vgm2ymm.genbinary");
	  String codec = Attribute.getStringOpt(node, defaults, "codec", "vgm2ymm.codec");
	  String drum = Attribute.getStringOpt(node, defaults, "dac2drum", "vgm2ymm.dac2drum");


	  if ((filename == null || filename.equals(""))) {
		  String m = "An input filename should be provided for vgm2ymm!";
		  log.error(m);
		  throw new Exception(m);
	  }
	  
	  if (filename != null) filename = path + File.separator + filename;
	  if (genbinary != null) genbinary = path + File.separator + genbinary;
	  
	  Binary bin = new Binary();
		Converter.filename = filename;
		Converter.genbinary = genbinary; 
		Converter.codec = codec;
		Converter.drumStr = drum;
		bin.bytes = Converter.run();
	return bin;
  }
}
