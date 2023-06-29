package com.widedot.toolbox.text.txt2bas.plugin;

import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileProcessor;

public class FileProcessorImpl implements FileProcessor {

  @Override
  public void doFileProcessor() {
    System.out.println("I'm a foo dooer!");
  }
}
