package com.widedot.m6809.gamebuilder.plugin.floppydisk.impl;

import com.widedot.m6809.gamebuilder.spi.DefaultFactory;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.FileFactory;
import com.widedot.m6809.gamebuilder.spi.FilePluginInterface;

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
