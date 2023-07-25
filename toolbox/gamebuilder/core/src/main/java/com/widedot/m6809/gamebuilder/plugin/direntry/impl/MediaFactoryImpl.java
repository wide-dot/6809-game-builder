package com.widedot.m6809.gamebuilder.plugin.direntry.impl;

import com.widedot.m6809.gamebuilder.spi.media.MediaFactory;
import com.widedot.m6809.gamebuilder.spi.media.MediaPluginInterface;

public class MediaFactoryImpl implements MediaFactory {

  @Override
  public String name() {
    return "direntry";
  }

  @Override
  public MediaPluginInterface build() {
    return new MediaImpl();
  }
}
