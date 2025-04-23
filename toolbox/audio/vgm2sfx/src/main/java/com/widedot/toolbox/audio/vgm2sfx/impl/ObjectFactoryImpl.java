package com.widedot.toolbox.audio.vgm2sfx.impl;

import com.widedot.m6809.gamebuilder.spi.ObjectFactory;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;

public class ObjectFactoryImpl implements ObjectFactory {

  @Override
  public String name() {
    return "vgm2sfx";
  }

  @Override
  public ObjectPluginInterface build() {
    return new ObjectImpl();
  }
}
