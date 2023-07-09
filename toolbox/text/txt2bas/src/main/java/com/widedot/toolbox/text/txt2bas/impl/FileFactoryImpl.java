package com.widedot.toolbox.text.txt2bas.impl;

import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileFactory;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FilePluginInterface;

public class FileFactoryImpl implements FileFactory {

  @Override
  public String name() {
    return "txt2bas";
  }

  @Override
  public FilePluginInterface build() {
    return new FileImpl();
  }
}
