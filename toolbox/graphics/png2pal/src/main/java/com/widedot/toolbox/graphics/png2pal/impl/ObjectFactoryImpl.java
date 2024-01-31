package com.widedot.toolbox.graphics.png2pal.impl;

import com.widedot.m6809.gamebuilder.spi.ObjectFactory;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;

public class ObjectFactoryImpl implements ObjectFactory {

  @Override
  public String name() {
    return "png2pal";
  }

  @Override
  public ObjectPluginInterface build() {
    return new ObjectImpl();
  }
}
