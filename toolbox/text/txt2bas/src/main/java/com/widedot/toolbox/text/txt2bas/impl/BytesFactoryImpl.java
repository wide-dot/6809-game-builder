package com.widedot.toolbox.text.txt2bas.impl;

import com.widedot.m6809.gamebuilder.spi.BytesFactory;
import com.widedot.m6809.gamebuilder.spi.BytesPluginInterface;

public class BytesFactoryImpl implements BytesFactory {

  @Override
  public String name() {
    return "txt2bas";
  }

  @Override
  public BytesPluginInterface build() {
    return new BytesImpl();
  }
}
