package com.widedot.m6809.gamebuilder.configuration.storage;

import java.io.File;
import java.util.HashMap;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.XMLConfiguration;
import org.apache.commons.configuration2.builder.fluent.Configurations;
import org.apache.commons.configuration2.tree.ImmutableNode;

import lombok.extern.slf4j.Slf4j;

public class Storages {
	
	public HashMap<String, Storage> storages;
	public HashMap<String, Fat> fats;
	
	public Storages() {
		storages = new HashMap<String, Storage>();
		fats = new HashMap<String, Fat>();
	}
	
	public void add(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		
		// parse each file of storage definition in a single object
	    List<HierarchicalConfiguration<ImmutableNode>> storageFileNodes = node.configurationsAt("storage");
	    for(HierarchicalConfiguration<ImmutableNode> storageFileNode : storageFileNodes)
    	{
			String filename = storageFileNode.getString("", null);
			if (filename == null) {
				throw new Exception("file value is missing for storage");
			}
			filename = path + filename;
			
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
	}
	
	public Storage get(String key) {
		return storages.get(key);
	}
	
}
