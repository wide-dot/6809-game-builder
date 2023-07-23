package com.widedot.m6809.gamebuilder.pluginloader;

import static java.util.Objects.requireNonNull;

import java.io.File;
import java.net.MalformedURLException;
import java.net.URI;
import java.net.URL;
import java.net.URLClassLoader;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Optional;
import java.util.ServiceLoader;
import java.util.concurrent.atomic.AtomicBoolean;

import com.widedot.m6809.gamebuilder.spi.ObjectFactory;
import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.FileFactory;
import com.widedot.m6809.gamebuilder.spi.media.MediaFactory;
import com.widedot.m6809.gamebuilder.spi.Plugin;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class PluginLoader {

	private final HashMap<String, DefaultFactory> defaultFactoryMap = new HashMap<>();
	private final HashMap<String, ObjectFactory> objectFactoryMap = new HashMap<>();
	private final HashMap<String, MediaFactory> mediaFactoryMap = new HashMap<>();
	private final HashMap<String, FileFactory> fileFactoryMap = new HashMap<>();
	
	private final File pluginsDir;
	private final AtomicBoolean loading = new AtomicBoolean();

	public PluginLoader(final File pluginsDir) {
		this.pluginsDir = pluginsDir;
	}

	public void loadPlugins() {
		log.info("Loading plugins ...");
		if (!pluginsDir.exists() || !pluginsDir.isDirectory()) {
			log.debug("Skipping Plugin Loading. Plugin dir not found: " + pluginsDir);
			return;
		}

		if (loading.compareAndSet(false, true)) {
			final File[] files = requireNonNull(pluginsDir.listFiles());
			for (File pluginDir : files) {
				if (pluginDir.isDirectory()) {
					loadPlugin(pluginDir);
				}
			}
		}
	}

	private void loadPlugin(final File pluginDir) {
		log.info("Loading plugin: " + pluginDir);
		final URLClassLoader pluginClassLoader = createPluginClassLoader(pluginDir);
		final ClassLoader currentClassLoader = Thread.currentThread().getContextClassLoader();
		try {
			Thread.currentThread().setContextClassLoader(pluginClassLoader);
			for (Plugin plugin : ServiceLoader.load(Plugin.class, pluginClassLoader)) {
				installPlugin(plugin);
			}
		} finally {
			Thread.currentThread().setContextClassLoader(currentClassLoader);
		}
	}

	private void installPlugin(final Plugin plugin) {
		log.debug("Installing plugin: {}", plugin.getClass().getName());
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

	private URLClassLoader createPluginClassLoader(File dir) {
		final URL[] urls = Arrays.stream(Optional.of(dir.listFiles()).orElse(new File[] {})).sorted().map(File::toURI)
				.map(this::toUrl).toArray(URL[]::new);

		return new PluginClassLoader(urls, getClass().getClassLoader());
	}

	private URL toUrl(final URI uri) {
		try {
			return uri.toURL();
		} catch (MalformedURLException e) {
			throw new RuntimeException(e);
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
