package com.widedot.m6809.gamebuilder.plugin.fd.impl;

import com.widedot.m6809.gamebuilder.spi.media.MediaFactory;
import com.widedot.m6809.gamebuilder.spi.media.MediaPluginInterface;

public class MediaFactoryImpl implements MediaFactory {

  @Override
  public String name() {
    return "fd";
  }

  @Override
  public MediaPluginInterface build() {
    return new MediaImpl();
  }
}
