package com.widedot.m6809.gamebuilder.plugin.file.impl;

import java.util.Arrays;
import java.util.List;

import com.widedot.m6809.gamebuilder.spi.FileFactory;
import com.widedot.m6809.gamebuilder.spi.Plugin;

public class FilePlugin implements Plugin {

  @Override
  public List<FileFactory> getFileFactories() {
    return Arrays.asList(
        new FileFactoryImpl()
    );
  }
}
