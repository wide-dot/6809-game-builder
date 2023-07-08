package com.widedot.m6809.gamebuilder.spi.fileprocessor;

public interface MediaFactory {

  String name();

  FilePluginInterface build();
}
