package com.widedot.m6809.gamebuilder.spi;

import java.util.List;

import org.apache.commons.configuration2.tree.ImmutableNode;

/**
 * Content that can name the pieces it is made of, so the arena packer can
 * cut between them.
 *
 * A part is one generated source and the symbol it defines. Sources rather
 * than bytes : regrouping sources and reassembling keeps every routine whole
 * and every relocation valid, where cutting an assembled binary would do
 * neither.
 */
public interface PartsPluginInterface {

	/** @return one {path, symbol} per part, in declaration order */
	List<String[]> getParts(ImmutableNode node, BuildContext ctx) throws Exception;
}
