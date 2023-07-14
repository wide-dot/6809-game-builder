package com.widedot.m6809.gamebuilder.plugin.cksumfd640.impl;

import com.widedot.m6809.gamebuilder.spi.BytesFactory;
import com.widedot.m6809.gamebuilder.spi.BytesPluginInterface;

public class BytesFactoryImpl implements BytesFactory {

  @Override
  public String name() {
    return "cksumfd640";
  }

  @Override
  public BytesPluginInterface build() {
    return new BytesImpl();
  }
}
