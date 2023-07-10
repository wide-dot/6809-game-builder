package com.widedot.m6809.gamebuilder.plugin.media.impl;

import java.util.Arrays;
import java.util.List;

import com.widedot.m6809.gamebuilder.spi.EmptyFactory;
import com.widedot.m6809.gamebuilder.spi.Plugin;

public class EmptyPlugin implements Plugin {

  @Override
  public List<EmptyFactory> getEmptyFactories() {
    return Arrays.asList(
        new EmptyFactoryImpl()
    );
  }
}
