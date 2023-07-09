package com.widedot.m6809.gamebuilder.plugin.media.impl;

import java.util.Arrays;
import java.util.List;
import com.widedot.m6809.gamebuilder.spi.Plugin;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.EmptyFactory;

public class EmptyPlugin implements Plugin {

  @Override
  public List<EmptyFactory> getEmptyFactories() {
    return Arrays.asList(
        new EmptyFactoryImpl()
    );
  }
}
