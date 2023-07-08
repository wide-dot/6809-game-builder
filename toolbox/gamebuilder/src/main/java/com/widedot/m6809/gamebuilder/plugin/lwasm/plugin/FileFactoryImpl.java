package com.widedot.m6809.gamebuilder.plugin.lwasm.plugin;

import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileFactory;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FilePluginInterface;

public class FileFactoryImpl implements FileFactory {

  @Override
  public String name() {
    return "lwasm";
  }

  @Override
  public FilePluginInterface build() {
    return new FileImpl();
  }
}
