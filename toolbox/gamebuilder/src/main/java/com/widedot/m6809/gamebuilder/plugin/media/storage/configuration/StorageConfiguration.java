package com.widedot.m6809.gamebuilder.plugin.media.storage.configuration;

import java.io.File;
import java.util.HashMap;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.XMLConfiguration;
import org.apache.commons.configuration2.builder.fluent.Configurations;
import org.apache.commons.configuration2.tree.ImmutableNode;

import lombok.extern.slf4j.Slf4j;

public class StorageConfiguration {
	
	public HashMap<String, Storage> storages;
	public HashMap<String, Fat> fats;
	
	public StorageConfiguration(String filename) throws Exception {
		storages = new HashMap<String, Storage>();
		fats = new HashMap<String, Fat>();

		File file = new File(filename);
		if (!file.exists() || file.isDirectory()) {
			throw new Exception("File "+filename+" does not exists !");
		}

		Configurations configs = new Configurations();
	    XMLConfiguration childNode = configs.xml(file);		

   	    List<HierarchicalConfiguration<ImmutableNode>> fatNodes = childNode.configurationsAt("fat");
       	for(HierarchicalConfiguration<ImmutableNode> fatNode : fatNodes)
       	{	
       		Fat fat = new Fat(fatNode);
		    fats.put(fat.name, fat);
       	}
	    
		HashMap<String, Interleave> interleaves = new HashMap<String, Interleave>();
   	    List<HierarchicalConfiguration<ImmutableNode>> interleaveNodes = childNode.configurationsAt("interleave");
       	for(HierarchicalConfiguration<ImmutableNode> interleaveNode : interleaveNodes)
       	{	
		    Interleave interleave = new Interleave(interleaveNode);
		    interleaves.put(interleave.name, interleave);
       	}
    	
  	    List<HierarchicalConfiguration<ImmutableNode>> storageNodes = childNode.configurationsAt("storage");
       	for(HierarchicalConfiguration<ImmutableNode> storageNode : storageNodes)
       	{	
		    Storage storage = new Storage(storageNode, interleaves);
		    storages.put(storage.name, storage);
       	}
	}
	
	public Storage get(String key) {
		return storages.get(key);
	}
	
}
