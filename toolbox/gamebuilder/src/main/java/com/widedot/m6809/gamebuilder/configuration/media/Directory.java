package com.widedot.m6809.gamebuilder.configuration.media;

import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.configuration.target.Defaults;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Directory {
	
	public String fat;
	public String diskName;
	public String section;

	public List<File> files;
	
	public Directory(HierarchicalConfiguration<ImmutableNode> node, String path, Defaults defaults) throws Exception {
		
		// load attributes
		section = node.getString("[@section]", null);
		fat = node.getString("[@fat]", null);
		if (fat != null) diskName = node.getString("[@diskname]", null);

   		log.debug("fat: {} \t diskname: {} \t section: {}", fat, diskName, section);
		
   		// controls
		if (section == null) {
			throw new Exception("section is missing for directory");
		}		

		if (diskName == null) {
			throw new Exception("diskname is missing for directory");
		}
		
   		// load sub-elements
		files = new ArrayList<File>();
	    List<HierarchicalConfiguration<ImmutableNode>> fileList = node.configurationsAt("file");
    	for(HierarchicalConfiguration<ImmutableNode> file : fileList)
    	{
    		files.add(new File(file, path, defaults));
    	}
	}
	
	public boolean isFat() {
		return (fat!=null);
	}
}

