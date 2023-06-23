package com.widedot.m6809.gamebuilder.configuration.target;

import java.util.Collection;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Settings;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Defaults {

	public HashMap<String, String> values;
	
	public Defaults() {
		values = new HashMap<String, String>();
	}
	
	public void add(HierarchicalConfiguration<ImmutableNode> node) throws Exception {
	    List<HierarchicalConfiguration<ImmutableNode>> defaults = node.configurationsAt("defaults");
    	for(HierarchicalConfiguration<ImmutableNode> defaultTags : defaults)
    	{
    		 Iterator<String> keyIter = defaultTags.getKeys();
    		    String key;
    		    while (keyIter.hasNext()) {
    		        key = keyIter.next();
    		        Object prop = defaultTags.getProperty(key);
    		        if(prop instanceof Collection) {
    		                List<String> valList = (List<String>) prop;
    		                for(String value : valList){
    		                	values.put(key, value);
    		                	log.debug("key: {} value: {}", key, value);
    		                }
    		        } else {
    		            values.put(key, prop.toString());
    		            log.debug("key: {} value: {}", key, prop.toString());
    		        }
    		    }
    	}
	}
	
    public Integer getInteger(String key) {
    	return (Settings.values.containsKey(key)?Integer.parseInt(Settings.values.get(key)):0);
    }
    
    public String getString(String key) {
    	return (Settings.values.containsKey(key)?Settings.values.get(key):"");
    }	
}
