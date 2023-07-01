package com.widedot.m6809.gamebuilder.plugins;

import java.util.HashMap;
import java.util.Map;
import java.util.ServiceLoader;

import com.widedot.m6809.gamebuilder.spi.Plugin;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileProcessorFactory;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class EmbededPluginLoader {

	private final Map<String, FileProcessorFactory> fileProcessorFactoryMap = new HashMap<>();

	public EmbededPluginLoader() {
	}

	public void loadPlugins() {
		log.info("Loading embeded plugins");
		for (Plugin plugin : ServiceLoader.load(Plugin.class)) {
			installPlugin(plugin);
		}
	}

	private void installPlugin(final Plugin plugin) {
		log.info("Installing plugin: " + plugin.getClass().getName());
		for (FileProcessorFactory f : plugin.getFileProcessorFactories()) {
			fileProcessorFactoryMap.put(f.name(), f);
		}
	}

	public FileProcessorFactory getFileProcessorFactory(String name) {
		FileProcessorFactory f = fileProcessorFactoryMap.get(name);
		if (f == null) log.error("Factory: {} not loaded!", name);
		return f;
	}
}
