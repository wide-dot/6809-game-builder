package com.widedot.m6809.gamebuilder.plugin.includebin.impl;

import com.widedot.m6809.gamebuilder.spi.FileFactory;
import com.widedot.m6809.gamebuilder.spi.FilePluginInterface;

public class FileFactoryImpl implements FileFactory {

  @Override
  public String name() {
    return "includebin";
  }

  @Override
  public FilePluginInterface build() {
    return new FileImpl();
  }
}
