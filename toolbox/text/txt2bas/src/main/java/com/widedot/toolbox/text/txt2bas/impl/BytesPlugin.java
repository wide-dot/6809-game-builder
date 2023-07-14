package com.widedot.toolbox.text.txt2bas.impl;

import java.util.Arrays;
import java.util.List;

import com.widedot.m6809.gamebuilder.spi.BytesFactory;
import com.widedot.m6809.gamebuilder.spi.Plugin;

public class BytesPlugin implements Plugin {

  @Override
  public List<BytesFactory> getBytesFactories() {
    return Arrays.asList(
        new BytesFactoryImpl()
    );
  }
}
