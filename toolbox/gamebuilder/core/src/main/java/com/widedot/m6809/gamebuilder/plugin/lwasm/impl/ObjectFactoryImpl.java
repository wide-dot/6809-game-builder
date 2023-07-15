package com.widedot.m6809.gamebuilder.plugin.lwasm.impl;

import com.widedot.m6809.gamebuilder.spi.ObjectFactory;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;

public class ObjectFactoryImpl implements ObjectFactory {

  @Override
  public String name() {
    return "lwasm";
  }

  @Override
  public ObjectPluginInterface build() {
    return new ObjectImpl();
  }
}
