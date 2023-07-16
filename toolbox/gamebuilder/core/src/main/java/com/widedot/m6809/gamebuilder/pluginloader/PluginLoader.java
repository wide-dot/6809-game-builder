package com.widedot.m6809.gamebuilder.pluginloader;

import static java.util.Objects.requireNonNull;

import java.io.File;
import java.net.MalformedURLException;
import java.net.URI;
import java.net.URL;
import java.net.URLClassLoader;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.ServiceLoader;
import java.util.concurrent.atomic.AtomicBoolean;

import com.widedot.m6809.gamebuilder.spi.DirEntryFactory;
import com.widedot.m6809.gamebuilder.spi.ObjectFactory;
import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.FileFactory;
import com.widedot.m6809.gamebuilder.spi.media.MediaFactory;
import com.widedot.m6809.gamebuilder.spi.Plugin;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class PluginLoader {

	private final Map<String, DefaultFactory> defaultFactoryMap = new HashMap<>();
	private final Map<String, ObjectFactory> objectFactoryMap = new HashMap<>();
	private final Map<String, MediaFactory> mediaFactoryMap = new HashMap<>();
	private final Map<String, DirEntryFactory> dirEntryFactoryMap = new HashMap<>();
	private final Map<String, FileFactory> fileFactoryMap = new HashMap<>();
	
	private final File pluginsDir;
	private final AtomicBoolean loading = new AtomicBoolean();

	public PluginLoader(final File pluginsDir) {
		this.pluginsDir = pluginsDir;
	}

	public void loadPlugins() {
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
		log.info("Installing plugin: " + plugin.getClass().getName());
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
		DefaultFactory f = defaultFactoryMap.get(name);
		if (f == null) log.debug("DefaultFactory: {} not an external plugin.", name);
		return f;
	}
	
	public ObjectFactory getObjectFactory(String name) {
		ObjectFactory f = objectFactoryMap.get(name);
		if (f == null) log.error("ObjectFactory: {} not loaded!", name);
		return f;
	}
	
	public MediaFactory getMediaFactory(String name) {
		MediaFactory f = mediaFactoryMap.get(name);
		if (f == null) log.debug("MediaFactory: {} not an external plugin.", name);
		return f;
	}
	
	public DirEntryFactory getDirEntryFactory(String name) {
		DirEntryFactory f = dirEntryFactoryMap.get(name);
		if (f == null) log.debug("DirEntryFactory: {} not an external plugin.", name);
		return f;
	}
	
	public FileFactory getFileFactory(String name) {
		FileFactory f = fileFactoryMap.get(name);
		if (f == null) log.debug("FileFactory: {} not an external plugin.", name);
		return f;
	}
}
