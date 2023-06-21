package com.widedot.m6809.gamebuilder.configuration;

import java.io.File;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.XMLConfiguration;
import org.apache.commons.configuration2.builder.fluent.Configurations;
import org.apache.commons.configuration2.tree.ImmutableNode;
import org.apache.commons.io.IOCase;
import org.apache.commons.io.filefilter.IOFileFilter;
import org.apache.commons.io.filefilter.WildcardFileFilter;

import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;
@Slf4j
public class Group {
	
	public static void recurse(HierarchicalConfiguration<ImmutableNode> node, String path, List<Ressource> ressources) throws Exception {
	    List<HierarchicalConfiguration<ImmutableNode>> binFields = node.configurationsAt("bin");
    	for(HierarchicalConfiguration<ImmutableNode> bin : binFields)
    	{	
    		String name = bin.getString("[@name]", null);
    		String file = bin.getString("", null);
    		
    		if (file == null) {
    			throw new Exception("filename value is missing for bin");
    		}
    		
    		file = path + file;
    		
    		if (name == null) {
    			name = FileUtil.getBasename(file);
    		}
    		
    		log.debug("bin: " + name + " " + file);
    		ressources.add(new Ressource(name, file, Ressource.BIN));
    	}
    	
	    List<HierarchicalConfiguration<ImmutableNode>> asmFields = node.configurationsAt("asm");
    	for(HierarchicalConfiguration<ImmutableNode> asm : asmFields)
    	{		
    		String name = asm.getString("[@name]", null);
    		String file = asm.getString("", null);
    		
    		if (file == null) {
    			throw new Exception("filename value is missing for asm");
    		}
    		
    		file = path + file;
    		
    		if (name == null) {
    			name = FileUtil.getBasename(file);
    		}
    		
    		log.debug("asm: " + name + " " + file);
    		ressources.add(new Ressource(name, file, Ressource.ASM));
    	}
    	
	    List<HierarchicalConfiguration<ImmutableNode>> dirFields = node.configurationsAt("dir");
    	for(HierarchicalConfiguration<ImmutableNode> dir : dirFields)
    	{		
    		String dirName = dir.getString("", null);
    		if (dirName == null) {
    			throw new Exception("directory value is missing for dir");
    		}
    		
    		String type = dir.getString("[@type]", null);
    		if (type == null) {
    			throw new Exception("type (asm or bin) is missing for dir " + dirName);
    		}

    		dirName = path + dirName; 
    		
    		String[] filters = dir.getString("[@filter]", "*").split(",");
    		log.debug("dir: " + dirName + " filter: " + Arrays.toString(filters));
    		
    		File dirFile = new File(dirName);
    		if (!dirFile.exists() || !dirFile.isDirectory()) {
    			throw new Exception("dir " + dirName + " does not exists !");
    		}
    		IOFileFilter wildCardFilter = new WildcardFileFilter(filters, IOCase.INSENSITIVE);

    		String[] files = dirFile.list(wildCardFilter);
    		for (int i = 0; i < files.length; i++) {
    			log.debug("|_ asm: " + files[i]);
    		    ressources.add(new Ressource(FileUtil.getBasename(files[i]), dirName + "/" + files[i], type));
    		}
    	}
    	
	    List<HierarchicalConfiguration<ImmutableNode>> groupFields = node.configurationsAt("group");
    	for(HierarchicalConfiguration<ImmutableNode> group : groupFields)
    	{		
    		File file = new File(path + "/" + group.getString("", null));
    		log.info("group: {}", file.getName());

    		if (!file.exists() || file.isDirectory()) {
    			throw new Exception("File " + file.getName() + " does not exists !");
    		}
      
    	    String currentPath = FileUtil.getDir(file);
    		
    	    // parse the xml
    		Configurations configs = new Configurations();
   		    XMLConfiguration config = configs.xml(file);
   		    recurse(config, currentPath, ressources);
    		log.info("end of group: {}", file.getName());
    	}
	}
}
