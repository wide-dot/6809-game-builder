package com.widedot.toolbox.audio.vgm2ymm.impl;

import com.widedot.m6809.gamebuilder.spi.ObjectFactory;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;

public class ObjectFactoryImpl implements ObjectFactory {

  @Override
  public String name() {
    return "vgm2ymm";
  }

  @Override
  public ObjectPluginInterface build() {
    return new ObjectImpl();
  }
}
