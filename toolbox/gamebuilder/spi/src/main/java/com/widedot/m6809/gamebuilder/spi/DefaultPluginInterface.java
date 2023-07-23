package com.widedot.m6809.gamebuilder.spi;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

public interface DefaultPluginInterface {

  void run(ImmutableNode element, String path, Defaults defaults, Defines defines) throws Exception;
}
