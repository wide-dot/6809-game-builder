package com.widedot.m6809.gamebuilder.plugin.bin.impl;

import com.widedot.m6809.gamebuilder.spi.ObjectFactory;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;

public class ObjectFactoryImpl implements ObjectFactory {

  @Override
  public String name() {
    return "bin";
  }

  @Override
  public ObjectPluginInterface build() {
    return new ObjectImpl();
  }
}
