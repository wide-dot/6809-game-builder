package com.widedot.m6809.gamebuilder.pluginloader;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.FileFactory;
import com.widedot.m6809.gamebuilder.spi.ObjectFactory;
import com.widedot.m6809.gamebuilder.spi.media.MediaFactory;

public class Plugins {

	public static DefaultFactory getDefaultFactory(String plugin) {
		// external plugin
		DefaultFactory defaultFactory = Settings.pluginLoader.getDefaultFactory(plugin);
	    if (defaultFactory == null) {
	    	// embeded plugin
	    	defaultFactory = Settings.embededPluginLoader.getDefaultFactory(plugin);
	    }
	    return defaultFactory;
	}
	
	public static ObjectFactory getObjectFactory(String plugin) {
		// external plugin
		ObjectFactory defaultFactory = Settings.pluginLoader.getObjectFactory(plugin);
	    if (defaultFactory == null) {
	    	// embeded plugin
	    	defaultFactory = Settings.embededPluginLoader.getObjectFactory(plugin);
	    }
	    return defaultFactory;
	}
	
	public static MediaFactory getMediaFactory(String plugin) {
		// external plugin
		MediaFactory defaultFactory = Settings.pluginLoader.getMediaFactory(plugin);
	    if (defaultFactory == null) {
	    	// embeded plugin
	    	defaultFactory = Settings.embededPluginLoader.getMediaFactory(plugin);
	    }
	    return defaultFactory;
	}
	
	public static FileFactory getFileFactory(String plugin) {
		// external plugin
		FileFactory defaultFactory = Settings.pluginLoader.getFileFactory(plugin);
	    if (defaultFactory == null) {
	    	// embeded plugin
	    	defaultFactory = Settings.embededPluginLoader.getFileFactory(plugin);
	    }
	    return defaultFactory;
	}
	
}
