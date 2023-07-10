package com.widedot.m6809.gamebuilder.plugin.lwasm.impl;

import com.widedot.m6809.gamebuilder.spi.FileFactory;
import com.widedot.m6809.gamebuilder.spi.FilePluginInterface;

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
