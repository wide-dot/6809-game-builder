package com.widedot.m6809.gamebuilder.spi.fileprocessor;

public interface FileFactory {

  String name();

  FilePluginInterface build();
}
