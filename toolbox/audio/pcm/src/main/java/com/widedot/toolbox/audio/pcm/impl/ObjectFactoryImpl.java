package com.widedot.toolbox.audio.pcm.impl;

import com.widedot.m6809.gamebuilder.spi.ObjectFactory;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;

public class ObjectFactoryImpl implements ObjectFactory {

  @Override
  public String name() {
    return "pcm";
  }

  @Override
  public ObjectPluginInterface build() {
    return new ObjectImpl();
  }
}
