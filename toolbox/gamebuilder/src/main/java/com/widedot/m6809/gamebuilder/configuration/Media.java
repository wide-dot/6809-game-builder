package com.widedot.m6809.gamebuilder.configuration;

import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Media {
	
	public String catalog;
	public Boot boot;
	public List<Package> packList;
	
	public Media(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		catalog = path + node.getString("[@catalog]", null);
		log.debug("catalog: "+catalog);
		
		List<HierarchicalConfiguration<ImmutableNode>> bootFields = node.configurationsAt("boot");
		if (bootFields.size()>1) {
			throw new Exception("No more than one boot definition is allowed inside a media.");
		}
		for(HierarchicalConfiguration<ImmutableNode> boot : bootFields) {
			this.boot = new Boot(boot, path);
		}
			
		packList = new ArrayList<Package>();
		// parse each packages
	    List<HierarchicalConfiguration<ImmutableNode>> packsFields = node.configurationsAt("packages");
    	for(HierarchicalConfiguration<ImmutableNode> packs : packsFields)
    	{
    		// parse each packages
    		List<HierarchicalConfiguration<ImmutableNode>> packFields = packs.configurationsAt("package");
    		for(HierarchicalConfiguration<ImmutableNode> pack : packFields)
    		{
    			packList.add(new Package(pack, path));
    		}
    	}
	}
}
