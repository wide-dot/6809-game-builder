package com.widedot.m6809.gamebuilder.plugin.media.impl;

import com.widedot.m6809.gamebuilder.spi.fileprocessor.EmptyFactory;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.EmptyPluginInterface;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileFactory;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FilePluginInterface;

public class EmptyFactoryImpl implements EmptyFactory {

  @Override
  public String name() {
    return "media";
  }

  @Override
  public EmptyPluginInterface build() {
    return new EmptyImpl();
  }
}
