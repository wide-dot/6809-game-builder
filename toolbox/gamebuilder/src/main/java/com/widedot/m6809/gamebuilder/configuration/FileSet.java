package com.widedot.m6809.gamebuilder.configuration;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.XMLConfiguration;
import org.apache.commons.configuration2.builder.fluent.Configurations;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;
@Slf4j
public class FileSet {
	public List<Ressource> ressources = new ArrayList<Ressource>();
	
	public FileSet(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		recurse(node, path);
	}
	
	public void recurse(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
	    List<HierarchicalConfiguration<ImmutableNode>> binFields = node.configurationsAt("bin");
    	for(HierarchicalConfiguration<ImmutableNode> bin : binFields)
    	{	
    		String name = bin.getString("[@name]", null);
    		String file = path + bin.getString("", null);
    		log.debug("bin: " + name + " " + file);
    		ressources.add(new Ressource(name, file, Ressource.BIN_INT));
    	}
    	
	    List<HierarchicalConfiguration<ImmutableNode>> asmFields = node.configurationsAt("asm");
    	for(HierarchicalConfiguration<ImmutableNode> asm : asmFields)
    	{		
    		String name = asm.getString("[@name]", null);
    		String file = path + asm.getString("", null);
    		log.debug("asm: " + name + " " + file);
    		ressources.add(new Ressource(name, file, Ressource.ASM_INT));
    	}
    	
	    List<HierarchicalConfiguration<ImmutableNode>> filesetFields = node.configurationsAt("fileset");
    	for(HierarchicalConfiguration<ImmutableNode> fileset : filesetFields)
    	{		
    		File file = new File(path + "/" + fileset.getString("", null));
    		log.info("Processing file {}", file.getName());

    		if (!file.exists() || file.isDirectory()) {
    			throw new Exception("File "+file.getName()+" does not exists !");
    		}
      
    	    String currentPath = FileUtil.getParentDir(file);
    		
    	    // parse the xml
    		Configurations configs = new Configurations();
   		    XMLConfiguration config = configs.xml(file);
   		    recurse(config, currentPath);
    	}
	}
}
