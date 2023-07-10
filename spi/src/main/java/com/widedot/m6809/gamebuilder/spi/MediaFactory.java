package com.widedot.m6809.gamebuilder.spi;

public interface MediaFactory {

  String name();

  FilePluginInterface build();
}
