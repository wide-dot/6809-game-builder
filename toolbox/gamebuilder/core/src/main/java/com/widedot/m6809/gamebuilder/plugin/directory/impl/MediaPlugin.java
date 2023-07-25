package com.widedot.m6809.gamebuilder.plugin.directory.impl;

import java.util.Arrays;
import java.util.List;

import com.widedot.m6809.gamebuilder.spi.media.MediaFactory;
import com.widedot.m6809.gamebuilder.spi.Plugin;

public class MediaPlugin implements Plugin {

  @Override
  public List<MediaFactory> getMediaFactories() {
    return Arrays.asList(
        new MediaFactoryImpl()
    );
  }
}
