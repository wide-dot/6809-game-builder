package com.widedot.m6809.gamebuilder.spi;

import org.apache.commons.configuration2.tree.ImmutableNode;


public interface DefaultPluginInterface {

  void run(ImmutableNode element, BuildContext ctx) throws Exception;
}
