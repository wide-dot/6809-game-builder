package com.widedot.m6809.gamebuilder.spi.media;

public interface MediaFactory {

  String name();

  MediaPluginInterface build();
}
