package com.widedot.m6809.gamebuilder.pluginloader;

import java.util.HashMap;
import java.util.Map;
import java.util.ServiceLoader;

import com.widedot.m6809.gamebuilder.spi.Plugin;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileFactory;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class EmbeddedPluginLoader {

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
		log.info("Installing plugin: " + plugin.getClass().getName());
		for (FileFactory f : plugin.getFileFactories()) {
			fileFactoryMap.put(f.name(), f);
		}
	}

	public FileFactory getFileProcessorFactory(String name) {
		FileFactory f = fileFactoryMap.get(name);
		if (f == null) log.error("Factory: {} not loaded!", name);
		return f;
	}
}
