package com.widedot.m6809.gamebuilder.plugin.cksumfd640.impl;

import com.widedot.m6809.gamebuilder.spi.ObjectFactory;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;

public class ObjectFactoryImpl implements ObjectFactory {

  @Override
  public String name() {
    return "cksumfd640";
  }

  @Override
  public ObjectPluginInterface build() {
    return new ObjectImpl();
  }
}
