package com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration;

import java.io.File;
import java.util.HashMap;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.config.XmlLoader;

public class Storages {

	public HashMap<String, Storage> storages;

	public Storages(String filename) throws Exception {
		storages = new HashMap<String, Storage>();

		File file = new File(filename);
		if (!file.exists() || file.isDirectory()) {
			throw new Exception("File " + filename + " does not exists !");
		}

		// same loader as the game configuration : source positions in the
		// errors, no DTD, no surprise interpolation
		XmlLoader.Result result = XmlLoader.load(file);
		for (ImmutableNode child : result.root.getChildren()) {
			if ("floppydisk".equals(child.getNodeName())) {
				Storage storage = new Storage(child, result.sources);
				storages.put(storage.model, storage);
			}
		}
	}

	public Storage get(String key) {
		return storages.get(key);
	}

}
