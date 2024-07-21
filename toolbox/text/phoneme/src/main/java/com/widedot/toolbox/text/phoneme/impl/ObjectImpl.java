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
	public ObjectDataInterface getObject(ImmutableNode node, String path, Defaults defaults, Defines defines)
			throws Exception {

		// read input xml
		String filename = Attribute.getStringOpt(node, defaults, "filename", "phoneme.filename");
		String genbinary = Attribute.getStringOpt(node, defaults, "genbinary", "phoneme.genbinary");
		String lang = Attribute.getString(node, defaults, "lang", "phoneme.lang", "fr");

		if (filename == null || filename.equals("")) {
			String m = "no filename provided for phoneme!";
			log.error(m);
			throw new Exception(m);
		}

		if (filename != null)
			filename = path + File.separator + filename;
		if (genbinary != null)
			genbinary = path + File.separator + genbinary;

		Binary bin = new Binary();

		PhonemePlugin.filename = filename;
		PhonemePlugin.genbinary = genbinary;
		PhonemePlugin.lang = lang;
		bin.bytes = PhonemePlugin.run();
		return bin;
	}
}
