package com.widedot.m6809.gamebuilder.configuration;

import java.io.File;
import java.util.HashMap;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.XMLConfiguration;
import org.apache.commons.configuration2.builder.fluent.Configurations;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.storage.fat.FatSettings;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Storages {
	
	public HashMap<String, Storage> storages = new HashMap<String, Storage>();
	public HashMap<String, FatSettings> fats = new HashMap<String, FatSettings>();
	
	public Storages() {
		
	}
	
	public void add(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		String filename = node.getString("", null);
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
       		FatSettings fat = new FatSettings(fatNode);
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
