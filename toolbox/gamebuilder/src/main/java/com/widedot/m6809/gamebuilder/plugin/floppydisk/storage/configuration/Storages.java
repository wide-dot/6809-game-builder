package com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration;

import java.io.File;
import java.util.HashMap;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.XMLConfiguration;
import org.apache.commons.configuration2.builder.fluent.Configurations;
import org.apache.commons.configuration2.tree.ImmutableNode;

public class Storages {
	
	public HashMap<String, Storage> storages;
	
	public Storages(String filename) throws Exception {
		storages = new HashMap<String, Storage>();

		File file = new File(filename);
		if (!file.exists() || file.isDirectory()) {
			throw new Exception("File "+filename+" does not exists !");
		}

		Configurations configs = new Configurations();
	    XMLConfiguration childNode = configs.xml(file);		
    	
  	    List<HierarchicalConfiguration<ImmutableNode>> storageNodes = childNode.configurationsAt("floppydisk");
       	for(HierarchicalConfiguration<ImmutableNode> storageNode : storageNodes)
       	{	
		    Storage storage = new Storage(storageNode);
		    storages.put(storage.model, storage);
       	}
	}
	
	public Storage get(String key) {
		return storages.get(key);
	}
	
}
