package com.widedot.m6809.gamebuilder.spi;

public interface BytesFactory {

  String name();

  BytesPluginInterface build();
}
