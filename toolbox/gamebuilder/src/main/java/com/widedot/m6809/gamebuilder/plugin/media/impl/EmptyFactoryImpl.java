package com.widedot.m6809.gamebuilder.plugin.media.impl;

import com.widedot.m6809.gamebuilder.spi.EmptyFactory;
import com.widedot.m6809.gamebuilder.spi.EmptyPluginInterface;
import com.widedot.m6809.gamebuilder.spi.FileFactory;
import com.widedot.m6809.gamebuilder.spi.FilePluginInterface;

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
