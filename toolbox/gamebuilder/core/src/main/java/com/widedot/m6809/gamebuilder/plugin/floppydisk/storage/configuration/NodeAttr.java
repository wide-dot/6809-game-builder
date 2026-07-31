package com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.configuration.SourceMap;
import com.widedot.m6809.gamebuilder.spi.configuration.Values;

/**
 * Attribute reads for the storage geometry file. The storage vocabulary is
 * not part of the game configuration contract (its element names would clash
 * with the config ones), so it reads its attributes directly — with the same
 * file:line error messages.
 */
final class NodeAttr {

	private NodeAttr() {
	}

	static String getString(ImmutableNode node, SourceMap sources, String name) throws Exception {
		String value = (String) node.getAttributes().get(name);
		if (value == null) {
			throw new Exception(sources.locate(node) + ": <" + node.getNodeName()
					+ "> attribute '" + name + "' is missing");
		}
		return value;
	}

	static int getInteger(ImmutableNode node, SourceMap sources, String name) throws Exception {
		return parse(node, sources, name, getString(node, sources, name));
	}

	static int getInteger(ImmutableNode node, SourceMap sources, String name, int fallback) throws Exception {
		String value = (String) node.getAttributes().get(name);
		if (value == null) {
			return fallback;
		}
		return parse(node, sources, name, value);
	}

	private static int parse(ImmutableNode node, SourceMap sources, String name, String value) throws Exception {
		try {
			return Values.parseInt(value);
		} catch (NumberFormatException e) {
			throw new Exception(sources.locate(node) + ": <" + node.getNodeName() + "> attribute '"
					+ name + "': '" + value + "' is not a number (decimal, 0x or $)");
		}
	}

	/** the single mandatory child of the given name */
	static ImmutableNode child(ImmutableNode node, SourceMap sources, String name) throws Exception {
		ImmutableNode found = null;
		for (ImmutableNode child : node.getChildren()) {
			if (name.equals(child.getNodeName())) {
				if (found != null) {
					throw new Exception(sources.locate(child) + ": only one <" + name
							+ "> is allowed per storage");
				}
				found = child;
			}
		}
		if (found == null) {
			throw new Exception(sources.locate(node) + ": <" + name + "> is mandatory for a storage");
		}
		return found;
	}
}
