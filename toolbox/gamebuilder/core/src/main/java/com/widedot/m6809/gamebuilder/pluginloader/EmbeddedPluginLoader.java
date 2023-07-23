package com.widedot.m6809.gamebuilder.pluginloader;

import java.util.HashMap;
import java.util.Map;
import java.util.ServiceLoader;

import com.widedot.m6809.gamebuilder.spi.ObjectFactory;
import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.FileFactory;
import com.widedot.m6809.gamebuilder.spi.media.MediaFactory;
import com.widedot.m6809.gamebuilder.spi.Plugin;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class EmbeddedPluginLoader {

	private final HashMap<String, DefaultFactory> defaultFactoryMap = new HashMap<>();
	private final HashMap<String, ObjectFactory> objectFactoryMap = new HashMap<>();
	private final HashMap<String, MediaFactory> mediaFactoryMap = new HashMap<>();
	private final HashMap<String, FileFactory> fileFactoryMap = new HashMap<>();

	public EmbeddedPluginLoader() {
	}

	public void loadPlugins() {
		log.info("Loading embeded plugins");
		for (Plugin plugin : ServiceLoader.load(Plugin.class)) {
			installPlugin(plugin);
		}
	}

	private void installPlugin(final Plugin plugin) {
		log.debug("Installing embedded plugin: {}", plugin.getClass().getName());
		for (DefaultFactory f : plugin.getDefaultFactories()) {
			defaultFactoryMap.put(f.name(), f);
			log.debug("plugin name: {}", f.name());
		}
		for (ObjectFactory f : plugin.getObjectFactories()) {
			objectFactoryMap.put(f.name(), f);
			log.debug("plugin name: {}", f.name());
		}
		for (MediaFactory f : plugin.getMediaFactories()) {
			mediaFactoryMap.put(f.name(), f);
			log.debug("plugin name: {}", f.name());
		}
		for (FileFactory f : plugin.getFileFactories()) {
			fileFactoryMap.put(f.name(), f);
			log.debug("plugin name: {}", f.name());
		}
	}

	public DefaultFactory getDefaultFactory(String name) {
		DefaultFactory f = defaultFactoryMap.get(name);
		if (f == null) log.debug("DefaultFactory: {} not loaded", name);
		return f;
	}
	
	public ObjectFactory getObjectFactory(String name) {
		ObjectFactory f = objectFactoryMap.get(name);
		if (f == null) log.debug("ObjectFactory: {} not loaded", name);
		return f;
	}
	
	public MediaFactory getMediaFactory(String name) {
		MediaFactory f = mediaFactoryMap.get(name);
		if (f == null) log.debug("MediaFactory: {} not loaded", name);
		return f;
	}
	
	public FileFactory getFileFactory(String name) {
		FileFactory f = fileFactoryMap.get(name);
		if (f == null) log.debug("FileFactory: {} not loaded", name);
		return f;
	}
}
