package com.widedot.m6809.gamebuilder.plugin.define.impl;

import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;

public class DefaultFactoryImpl implements DefaultFactory {

  @Override
  public String name() {
    return "define";
  }

  @Override
  public DefaultPluginInterface build() {
    return new DefaultImpl();
  }
}
