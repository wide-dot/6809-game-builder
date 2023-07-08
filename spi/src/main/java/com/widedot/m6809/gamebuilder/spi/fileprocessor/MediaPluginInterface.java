package com.widedot.m6809.gamebuilder.spi.fileprocessor;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

public interface MediaPluginInterface {

  byte[] doFileProcessor(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception;
}
