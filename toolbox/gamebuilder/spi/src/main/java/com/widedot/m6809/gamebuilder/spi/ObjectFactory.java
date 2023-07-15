package com.widedot.m6809.gamebuilder.spi;

public interface ObjectFactory {

  String name();

  ObjectPluginInterface build();
}
