package com.widedot.toolbox.audio.pcm.impl;

import java.io.File;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.toolbox.audio.pcm.Binary;
import com.widedot.toolbox.audio.pcm.Converter;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class ObjectImpl implements ObjectPluginInterface {

  @Override
  public ObjectDataInterface getObject(ImmutableNode node, String path, Defaults defaults, Defines defines) throws Exception {
	  
	//read input xml
	String filename = Attribute.getStringOpt(node, defaults, "filename", "pcm.filename");
	boolean downscale8To6Bit = Attribute.getBoolean(node, defaults, "bit8to6", "pcm.bit8to6", false);
	String genbinary = Attribute.getStringOpt(node, defaults, "genbinary", "pcm.genbinary");


	if ((filename == null || filename.equals(""))) {
		String m = "An input filename should be provided for pcm!";
		log.error(m);
		throw new Exception(m);
	}
	  
	if (filename != null) filename = path + File.separator + filename;
	if (genbinary != null) genbinary = path + File.separator + genbinary;
	  
	Binary bin = new Binary();
	  
	Converter.filename = filename;
	Converter.genbinary = genbinary; 
	Converter.downscale8To6Bit = downscale8To6Bit;
	bin.bytes = Converter.run();
	return bin;
  }
}
