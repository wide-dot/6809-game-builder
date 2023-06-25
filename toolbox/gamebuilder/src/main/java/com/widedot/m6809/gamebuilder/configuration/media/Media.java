package com.widedot.m6809.gamebuilder.configuration.media;

import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.configuration.target.Defaults;

public class Media {
	
	public String storage;
	public List<File> files;
	public List<Directory> directories;
	
	public Media(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults) throws Exception {
		
		storage = node.getString("[@storage]", null);
		if (storage == null) {
			throw new Exception("storage is missing for media");
		}
		
		files = new ArrayList<File>();

	    List<HierarchicalConfiguration<ImmutableNode>> fileList = node.configurationsAt("file");
    	for(HierarchicalConfiguration<ImmutableNode> file : fileList)
    	{
    		files.add(new File(file, path, defaults));
    	}
    	
    	directories = new ArrayList<Directory>();

	    List<HierarchicalConfiguration<ImmutableNode>> directoryList = node.configurationsAt("directory");
    	for(HierarchicalConfiguration<ImmutableNode> directory : directoryList)
    	{
    		directories.add(new Directory(directory, path, defaults));
    	}    	
	}
}

