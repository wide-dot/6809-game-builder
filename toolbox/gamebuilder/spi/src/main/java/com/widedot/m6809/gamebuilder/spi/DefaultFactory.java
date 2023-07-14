package com.widedot.m6809.gamebuilder.spi;

public interface DefaultFactory {

  String name();

  DefaultPluginInterface build();
}
