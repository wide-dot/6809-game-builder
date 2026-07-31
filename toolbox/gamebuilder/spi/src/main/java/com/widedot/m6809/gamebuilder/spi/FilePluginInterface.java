package com.widedot.m6809.gamebuilder.spi;

import java.io.File;

import org.apache.commons.configuration2.tree.ImmutableNode;


public interface FilePluginInterface {

  File getFile(ImmutableNode child, BuildContext ctx) throws Exception;
}
