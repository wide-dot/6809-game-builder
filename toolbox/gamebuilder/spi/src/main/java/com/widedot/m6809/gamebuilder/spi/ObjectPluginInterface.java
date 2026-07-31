package com.widedot.m6809.gamebuilder.spi;

import org.apache.commons.configuration2.tree.ImmutableNode;


public interface ObjectPluginInterface {

  ObjectDataInterface getObject(ImmutableNode child, BuildContext ctx) throws Exception;
}
