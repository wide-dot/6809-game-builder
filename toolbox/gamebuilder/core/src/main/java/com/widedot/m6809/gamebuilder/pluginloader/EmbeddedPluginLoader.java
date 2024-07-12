package com.widedot.m6809.gamebuilder.pluginloader;

import java.util.HashMap;
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
		log.debug("Loading embeded plugins ...");
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
		return defaultFactoryMap.get(name);
	}
	
	public ObjectFactory getObjectFactory(String name) {
		return objectFactoryMap.get(name);
	}
	
	public MediaFactory getMediaFactory(String name) {
		return mediaFactoryMap.get(name);
	}
	
	public FileFactory getFileFactory(String name) {
		return fileFactoryMap.get(name);
	}
}
