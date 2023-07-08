package com.widedot.m6809.gamebuilder.spi.fileprocessor;

public interface DirEntryFactory {

  String name();

  FilePluginInterface build();
}
