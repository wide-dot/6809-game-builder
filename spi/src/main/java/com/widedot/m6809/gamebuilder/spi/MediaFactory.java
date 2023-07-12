package com.widedot.m6809.gamebuilder.spi;

public interface MediaFactory {

  String name();

  MediaPluginInterface build();
}
