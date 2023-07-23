package com.widedot.m6809.gamebuilder.plugin.defaults.impl;

import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;

public class DefaultFactoryImpl implements DefaultFactory {

  @Override
  public String name() {
    return "default"; // this is the intended name, however package does not match due to java restriction (no default in package name)
  }

  @Override
  public DefaultPluginInterface build() {
    return new DefaultImpl();
  }
}
