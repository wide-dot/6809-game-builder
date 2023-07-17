package com.widedot.m6809.gamebuilder.plugin.sd.impl;

import com.widedot.m6809.gamebuilder.spi.media.MediaFactory;
import com.widedot.m6809.gamebuilder.spi.media.MediaPluginInterface;

public class MediaFactoryImpl implements MediaFactory {

  @Override
  public String name() {
    return "sd";
  }

  @Override
  public MediaPluginInterface build() {
    return new MediaImpl();
  }
}
