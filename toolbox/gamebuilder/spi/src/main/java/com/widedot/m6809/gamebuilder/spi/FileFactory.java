package com.widedot.m6809.gamebuilder.spi;

public interface FileFactory {

  String name();

  FilePluginInterface build();
}
