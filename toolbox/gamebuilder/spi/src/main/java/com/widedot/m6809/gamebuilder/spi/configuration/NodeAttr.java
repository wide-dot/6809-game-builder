package com.widedot.m6809.gamebuilder.spi.configuration;

import org.apache.commons.configuration2.tree.ImmutableNode;


/**
 * Attribute reads for the builder's DEFINITION files — the storage geometry,
 * the machines. Their vocabulary is not part of the game configuration
 * contract (their element names would clash with the config ones), so they
 * read their attributes directly — with the same file:line error messages.
 */
public final class NodeAttr {

	private NodeAttr() {
	}

	public static String getString(ImmutableNode node, SourceMap sources, String name) throws Exception {
		String value = (String) node.getAttributes().get(name);
		if (value == null) {
			throw new Exception(sources.locate(node) + ": <" + node.getNodeName()
					+ "> attribute '" + name + "' is missing");
		}
		return value;
	}

	public static int getInteger(ImmutableNode node, SourceMap sources, String name) throws Exception {
		return parse(node, sources, name, getString(node, sources, name));
	}

	public static int getInteger(ImmutableNode node, SourceMap sources, String name, int fallback) throws Exception {
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
	public static ImmutableNode child(ImmutableNode node, SourceMap sources, String name) throws Exception {
		ImmutableNode found = null;
		for (ImmutableNode child : node.getChildren()) {
			if (name.equals(child.getNodeName())) {
				if (found != null) {
					throw new Exception(sources.locate(child) + ": only one <" + name
							+ "> is allowed per <" + node.getNodeName() + ">");
				}
				found = child;
			}
		}
		if (found == null) {
			throw new Exception(sources.locate(node) + ": <" + name + "> is mandatory in a <"
					+ node.getNodeName() + ">");
		}
		return found;
	}
}
