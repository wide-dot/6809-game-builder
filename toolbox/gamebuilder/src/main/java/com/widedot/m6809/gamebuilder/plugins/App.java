package com.widedot.m6809.gamebuilder.plugins;

import java.io.File;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileProcessor;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileProcessorFactory;

/**
 * Launcher for javapluginquickstart
 */
public class App {

  public static void main(String[] args) {
    new App().run(args);
  }

  public void run(final String[] args) {
    System.out.println("Hello World!");

    String pluginsPath = "plugins";
    if (args.length > 0) {
      pluginsPath = args[0];
    }

    PluginLoader pluginLoader = new PluginLoader(new File(pluginsPath));
    pluginLoader.loadPlugins();

    FileProcessorFactory f = pluginLoader.getFileProcessorFactory("txt2bas");
    if (f == null) {
      System.err.println("No factories loaded!");
      return;
    }

    System.out.println("This is running from the plugin");
    final FileProcessor fileProcessor = f.build();
    fileProcessor.doFileProcessor();
  }
}
