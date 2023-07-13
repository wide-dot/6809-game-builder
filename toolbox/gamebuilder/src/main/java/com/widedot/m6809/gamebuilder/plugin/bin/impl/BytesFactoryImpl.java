package com.widedot.m6809.gamebuilder.plugin.bin.impl;

import com.widedot.m6809.gamebuilder.spi.BytesFactory;
import com.widedot.m6809.gamebuilder.spi.BytesPluginInterface;

public class BytesFactoryImpl implements BytesFactory {

  @Override
  public String name() {
    return "bin";
  }

  @Override
  public BytesPluginInterface build() {
    return new BytesImpl();
  }
}
