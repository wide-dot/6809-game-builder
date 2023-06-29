package com.widedot.toolbox.text.txt2bas.plugin;

import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileProcessor;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileProcessorFactory;

public class FileProcessorFactoryImpl implements FileProcessorFactory {

  @Override
  public String name() {
    return "txt2bas";
  }

  @Override
  public FileProcessor build() {
    return new FileProcessorImpl();
  }
}
