package com.widedot.m6809.gamebuilder.plugin.floppydisk.impl;

import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;

public class DefaultFactoryImpl implements DefaultFactory {

  @Override
  public String name() {
    return "floppydisk";
  }

  @Override
  public DefaultPluginInterface build() {
    return new DefaultImpl();
  }
}
