package com.widedot.m6809.gamebuilder;

import java.util.HashMap;

import com.widedot.m6809.gamebuilder.plugins.PluginLoader;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Settings {
	
    public static HashMap<String,String> values;
    public static PluginLoader pluginLoader;
    
    private static String[] mandatoryKeys = new String[]{"build.dir", "build.dir.tag", "plugin.dir", "plugin.package"};
    
    public static boolean isValid() {
    	
    	boolean state = true;
    	
    	for (int i = 0; i < mandatoryKeys.length; i++) {
    		if (values.get(mandatoryKeys[i]) == null || values.get(mandatoryKeys[i]).equals("")) {
    			log.error("Missing key:{} in settings.properties", mandatoryKeys[i]);
    			state = false;
    		}
    	}
    	
    	return state;
    }
}
