package com.widedot.m6809.gamebuilder.configuration.media;

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
	
	public static void recurse(HierarchicalConfiguration<ImmutableNode> node, String path, List<Resource> ressources) throws Exception {

		// read all known ressource files
		for (String type : Resource.id.keySet()) {
			loadFile(type, node, path, ressources);
		}
    	
	    List<HierarchicalConfiguration<ImmutableNode>> groupFields = node.configurationsAt("group");
    	for(HierarchicalConfiguration<ImmutableNode> group : groupFields)
    	{		
			// a group is an xml definition declared outside of the current xml, it may be recursive
			String filename = group.getString("", null);
    		if (filename == null) {
    			throw new Exception("no value for file.");
    		}

			log.info("group: {}", filename);
    		File file = new File(path + File.separator + filename);
    		if (!file.exists() || file.isDirectory()) {
    			throw new Exception("File " + file.getName() + " does not exists !");
    		}
      
    	    String currentPath = FileUtil.getDir(file);
    		
    	    // parse the sub xml file
    		Configurations configs = new Configurations();
   		    XMLConfiguration config = configs.xml(file);
   		    recurse(config, currentPath, ressources);
    		log.info("end of group: {}", file.getName());
    	}
	}

	private static void loadFile(String type, HierarchicalConfiguration<ImmutableNode> node, String path, List<Resource> ressources) throws Exception {
		    List<HierarchicalConfiguration<ImmutableNode>> nodes = node.configurationsAt(type);
    	for(HierarchicalConfiguration<ImmutableNode> element : nodes)
    	{	
    		String filename = element.getString("", null);
    		if (filename == null) {
    			throw new Exception("no value for file or directory.");
    		}
    		
    		filename = path + filename;
			File file = new File(filename);

			if (!file.exists()) {
				throw new Exception("file or directory does not exists: " + filename);
			}
    		
			if (file.isDirectory()) {

				// all files in the directory
				String[] filters = element.getString("[@filter]", "*").split(","); // when no filter is set, will take al files ("*")
				IOFileFilter wildCardFilter = new WildcardFileFilter(filters, IOCase.INSENSITIVE);
				log.debug("dir: {} filter: {}", filename, Arrays.toString(filters));

				String[] filenames = file.list(wildCardFilter);

				for (int i = 0; i < filenames.length; i++) {
					filename = filename + File.separator + filenames[i];
					file = new File(filename);
					if (!file.isDirectory()) {
						log.debug("|_ type: {} file: {}", type, filename);
						ressources.add(new Resource(filename, type));
					}
				}

			} else {

				// simple file
				log.debug("type: {} file: {}", type, filename);
				ressources.add(new Resource(filename, type));				
			}
    	}
	}
}
