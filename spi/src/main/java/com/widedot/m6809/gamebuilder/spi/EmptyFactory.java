package com.widedot.m6809.gamebuilder.spi;

public interface EmptyFactory {

  String name();

  EmptyPluginInterface build();
}
