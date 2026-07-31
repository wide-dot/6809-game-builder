package com.widedot.m6809.gamebuilder.spi.media;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;


public interface MediaPluginInterface {

  void run(ImmutableNode child, BuildContext ctx, MediaDataInterface media) throws Exception;
}
