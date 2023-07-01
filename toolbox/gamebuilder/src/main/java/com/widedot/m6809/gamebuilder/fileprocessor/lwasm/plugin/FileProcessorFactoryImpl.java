package com.widedot.m6809.gamebuilder.fileprocessor.lwasm.plugin;

import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileProcessor;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileProcessorFactory;

public class FileProcessorFactoryImpl implements FileProcessorFactory {

  @Override
  public String name() {
    return "lwasm";
  }

  @Override
  public FileProcessor build() {
    return new FileProcessorImpl();
  }
}
