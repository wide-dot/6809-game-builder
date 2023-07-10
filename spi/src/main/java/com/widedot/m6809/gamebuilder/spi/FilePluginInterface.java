package com.widedot.m6809.gamebuilder.spi;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

public interface FilePluginInterface {

  byte[] doFileProcessor(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception;
}
