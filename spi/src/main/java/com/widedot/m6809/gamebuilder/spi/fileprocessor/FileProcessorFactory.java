package com.widedot.m6809.gamebuilder.spi.fileprocessor;

public interface FileProcessorFactory {

  String name();

  FileProcessor build();
}
