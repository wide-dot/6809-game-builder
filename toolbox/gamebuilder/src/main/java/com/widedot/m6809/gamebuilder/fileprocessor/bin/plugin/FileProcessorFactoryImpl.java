package com.widedot.m6809.gamebuilder.fileprocessor.bin.plugin;

import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileProcessor;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileProcessorFactory;

public class FileProcessorFactoryImpl implements FileProcessorFactory {

  @Override
  public String name() {
    return "bin";
  }

  @Override
  public FileProcessor build() {
    return new FileProcessorImpl();
  }
}
