package com.widedot.m6809.gamebuilder.spi.media;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;

public interface MediaPluginInterface {

  void run(ImmutableNode child, String path, Defaults defaults, Defines defines, MediaDataInterface media) throws Exception;
}
