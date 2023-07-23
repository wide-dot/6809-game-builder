package com.widedot.m6809.gamebuilder.plugin.define.impl;

import java.util.Arrays;
import java.util.List;

import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.Plugin;

public class DefaultPlugin implements Plugin {

  @Override
  public List<DefaultFactory> getDefaultFactories() {
    return Arrays.asList(
        new DefaultFactoryImpl()
    );
  }
}
