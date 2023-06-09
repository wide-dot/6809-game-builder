package com.widedot.m6809.gamebuilder.configuration;

import java.io.File;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.XMLConfiguration;
import org.apache.commons.configuration2.builder.fluent.Configurations;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.util.FileUtil;
import com.widedot.m6809.util.math.Hex;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class FileGroup {
	
	public String filename;
	public File file;
	public String name;
	public String store;
	public String codec;
	public FileSet fileset;
	
	public FileGroup(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		filename = node.getString("", null);
		if (filename == null) {
			throw new Exception("file value is missing for filegroup");
		}
		filename = path + filename;
		
		file = new File(filename);
		if (!file.exists() || file.isDirectory()) {
			throw new Exception("File "+file.getName()+" does not exists !");
		}
		
		parse();
	}
	
	private void parse() throws Exception {
	    String path = FileUtil.getParentDir(file);
		
	    // parse the xml
		Configurations configs = new Configurations();
	    XMLConfiguration node = configs.xml(file);		
	    
	    List<HierarchicalConfiguration<ImmutableNode>> pkgFields = node.configurationsAt("filegroup");
    	for(HierarchicalConfiguration<ImmutableNode> pkg : pkgFields)
    	{	
    		// for all all types
    		name = pkg.getString("[@name]", null);
    		if (name == null) {
    			throw new Exception("name is missing for filegroup");
    		}
    		
    		codec = pkg.getString("[@codec]", "none");
    		
    		log.debug("name: " + name + " codec: " + codec);
    		
    		fileset = new FileSet(pkg, path);
    	}
	}
}
