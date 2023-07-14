package com.widedot.m6809.gamebuilder.spi;

public interface DirEntryFactory {

  String name();

  DirEntryPluginInterface build();
}
