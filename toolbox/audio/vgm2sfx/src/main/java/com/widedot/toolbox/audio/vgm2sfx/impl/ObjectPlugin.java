package com.widedot.toolbox.audio.vgm2sfx.impl;

import java.util.Arrays;
import java.util.List;

import com.widedot.m6809.gamebuilder.spi.ObjectFactory;
import com.widedot.m6809.gamebuilder.spi.Plugin;

public class ObjectPlugin implements Plugin {

  @Override
  public List<ObjectFactory> getObjectFactories() {
    return Arrays.asList(
        new ObjectFactoryImpl()
    );
  }
}
