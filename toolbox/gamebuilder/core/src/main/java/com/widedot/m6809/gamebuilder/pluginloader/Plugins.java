package com.widedot.m6809.gamebuilder.pluginloader;

import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.FileFactory;
import com.widedot.m6809.gamebuilder.spi.ObjectFactory;
import com.widedot.m6809.gamebuilder.spi.media.MediaFactory;

public class Plugins {

	/**
	 * The plugin registry is loaded once per JVM and never mutated afterwards :
	 * unlike build state it is not per build, so it legitimately stays static.
	 */
	private static PluginLoader external;
	private static EmbeddedPluginLoader embedded;

	public static void register(PluginLoader externalLoader, EmbeddedPluginLoader embeddedLoader) {
		external = externalLoader;
		embedded = embeddedLoader;
	}


	public static DefaultFactory getDefaultFactory(String plugin) {
		// external plugin
		DefaultFactory defaultFactory = external.getDefaultFactory(plugin);
	    if (defaultFactory == null) {
	    	// embeded plugin
	    	defaultFactory = embedded.getDefaultFactory(plugin);
	    }
	    return defaultFactory;
	}
	
	public static ObjectFactory getObjectFactory(String plugin) {
		// external plugin
		ObjectFactory defaultFactory = external.getObjectFactory(plugin);
	    if (defaultFactory == null) {
	    	// embeded plugin
	    	defaultFactory = embedded.getObjectFactory(plugin);
	    }
	    return defaultFactory;
	}
	
	public static MediaFactory getMediaFactory(String plugin) {
		// external plugin
		MediaFactory defaultFactory = external.getMediaFactory(plugin);
	    if (defaultFactory == null) {
	    	// embeded plugin
	    	defaultFactory = embedded.getMediaFactory(plugin);
	    }
	    return defaultFactory;
	}
	
	public static FileFactory getFileFactory(String plugin) {
		// external plugin
		FileFactory defaultFactory = external.getFileFactory(plugin);
	    if (defaultFactory == null) {
	    	// embeded plugin
	    	defaultFactory = embedded.getFileFactory(plugin);
	    }
	    return defaultFactory;
	}
	
}
