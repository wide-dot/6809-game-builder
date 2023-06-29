package com.widedot.m6809.gamebuilder.plugins;

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
import com.widedot.m6809.gamebuilder.spi.Plugin;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileProcessorFactory;

public class PluginLoader {

  private final Map<String, FileProcessorFactory> fileProcessorFactoryMap = new HashMap<>();
  private final File pluginsDir;
  private final AtomicBoolean loading = new AtomicBoolean();

  public PluginLoader(final File pluginsDir) {
    this.pluginsDir = pluginsDir;
  }

  public void loadPlugins() {
    if (!pluginsDir.exists() || !pluginsDir.isDirectory()) {
      System.err.println("Skipping Plugin Loading. Plugin dir not found: " + pluginsDir);
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
    System.out.println("Loading plugin: " + pluginDir);
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
    System.out.println("Installing plugin: " + plugin.getClass().getName());
    for (FileProcessorFactory f : plugin.getFileProcessorFactories()) {
    	fileProcessorFactoryMap.put(f.name(), f);
    }
  }

  private URLClassLoader createPluginClassLoader(File dir) {
    final URL[] urls = Arrays.stream(Optional.of(dir.listFiles()).orElse(new File[]{}))
        .sorted()
        .map(File::toURI)
        .map(this::toUrl)
        .toArray(URL[]::new);

    return new PluginClassLoader(urls, getClass().getClassLoader());
  }

  private URL toUrl(final URI uri) {
    try {
      return uri.toURL();
    } catch (MalformedURLException e) {
      throw new RuntimeException(e);
    }
  }

  public FileProcessorFactory getFileProcessorFactory(String name) {
    return fileProcessorFactoryMap.get(name);
  }
}
