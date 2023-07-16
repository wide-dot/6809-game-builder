package com.widedot.m6809.gamebuilder.pluginloader;

import java.util.HashMap;
import java.util.Map;
import java.util.ServiceLoader;

import com.widedot.m6809.gamebuilder.spi.DirEntryFactory;
import com.widedot.m6809.gamebuilder.spi.ObjectFactory;
import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.FileFactory;
import com.widedot.m6809.gamebuilder.spi.media.MediaFactory;
import com.widedot.m6809.gamebuilder.spi.Plugin;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class EmbeddedPluginLoader {

	private final Map<String, DefaultFactory> defaultFactoryMap = new HashMap<>();
	private final Map<String, ObjectFactory> objectFactoryMap = new HashMap<>();
	private final Map<String, MediaFactory> mediaFactoryMap = new HashMap<>();
	private final Map<String, DirEntryFactory> dirEntryFactoryMap = new HashMap<>();
	private final Map<String, FileFactory> fileFactoryMap = new HashMap<>();

	public EmbeddedPluginLoader() {
	}

	public void loadPlugins() {
		log.info("Loading embeded plugins");
		for (Plugin plugin : ServiceLoader.load(Plugin.class)) {
			installPlugin(plugin);
		}
	}

	private void installPlugin(final Plugin plugin) {
		log.info("Installing embedded plugin: " + plugin.getClass().getName());
		for (DefaultFactory f : plugin.getDefaultFactories()) {
			defaultFactoryMap.put(f.name(), f);
		}
		for (ObjectFactory f : plugin.getObjectFactories()) {
			objectFactoryMap.put(f.name(), f);
		}
		for (MediaFactory f : plugin.getMediaFactories()) {
			mediaFactoryMap.put(f.name(), f);
		}
		for (DirEntryFactory f : plugin.getDirEntryFactories()) {
			dirEntryFactoryMap.put(f.name(), f);
		}
		for (FileFactory f : plugin.getFileFactories()) {
			fileFactoryMap.put(f.name(), f);
		}
	}

	public DefaultFactory getDefaultFactory(String name) {
		DefaultFactory f = defaultFactoryMap.get(name);
		if (f == null) log.error("DefaultFactory: {} not loaded!", name);
		return f;
	}
	
	public ObjectFactory getObjectFactory(String name) {
		ObjectFactory f = objectFactoryMap.get(name);
		if (f == null) log.error("ObjectFactory: {} not loaded!", name);
		return f;
	}
	
	public MediaFactory getMediaFactory(String name) {
		MediaFactory f = mediaFactoryMap.get(name);
		if (f == null) log.error("MediaFactory: {} not loaded!", name);
		return f;
	}
	
	public DirEntryFactory getDirEntryFactory(String name) {
		DirEntryFactory f = dirEntryFactoryMap.get(name);
		if (f == null) log.error("irEntryFactory: {} not loaded!", name);
		return f;
	}
	
	public FileFactory getFileFactory(String name) {
		FileFactory f = fileFactoryMap.get(name);
		if (f == null) log.error("FileFactory: {} not loaded!", name);
		return f;
	}
}
