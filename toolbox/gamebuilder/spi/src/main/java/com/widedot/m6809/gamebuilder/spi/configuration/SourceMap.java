package com.widedot.m6809.gamebuilder.spi.configuration;

import java.util.IdentityHashMap;
import java.util.Map;

import org.apache.commons.configuration2.tree.ImmutableNode;

/**
 * Source positions of the configuration tree.
 *
 * ImmutableNode carries no location, so the loader records one per node here,
 * keyed by identity. Error messages use {@link #locate} to point at the exact
 * file and line instead of leaving the user to search a whole configuration.
 */
public class SourceMap {

	private final String file;
	private final Map<ImmutableNode, int[]> positions = new IdentityHashMap<ImmutableNode, int[]>();

	public SourceMap(String file) {
		this.file = file;
	}

	public void put(ImmutableNode node, int line, int column) {
		positions.put(node, new int[] { line, column });
	}

	/**
	 * @return "file:line" for a known node, the bare file name otherwise —
	 *         always usable in a message
	 */
	public String locate(ImmutableNode node) {
		int[] p = positions.get(node);
		return p == null ? file : file + ":" + p[0];
	}

	public String getFile() {
		return file;
	}
}
