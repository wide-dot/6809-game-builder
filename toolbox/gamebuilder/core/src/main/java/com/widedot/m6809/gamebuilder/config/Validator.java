package com.widedot.m6809.gamebuilder.config;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Handlers;
import com.widedot.m6809.gamebuilder.spi.configuration.SourceMap;
import com.widedot.m6809.gamebuilder.spi.configuration.Values;
import com.widedot.m6809.gamebuilder.spi.schema.ElementSpec;
import com.widedot.m6809.gamebuilder.spi.schema.ElementSpec.AttrSpec;

/**
 * Checks a configuration tree against the declared element specs, before
 * anything runs.
 *
 * Until now an unknown attribute was silently ignored : a typo made the
 * handler fall back to its default, which is exactly how the direntry size
 * guard stayed inactive for years. Every error is reported at once, with its
 * source position, instead of one per run.
 */
public final class Validator {

	private Validator() {
	}

	public static void validate(ImmutableNode root, SourceMap sources) throws Exception {
		List<String> errors = new ArrayList<String>();
		walk(root, sources, errors);
		if (!errors.isEmpty()) {
			throw new Exception("Invalid configuration:\n  " + String.join("\n  ", errors));
		}
	}

	private static void walk(ImmutableNode node, SourceMap sources, List<String> errors) {
		ElementSpec spec = Handlers.spec(node.getNodeName());

		if (spec != null) {
			for (Map.Entry<String, Object> attr : node.getAttributes().entrySet()) {
				String name = attr.getKey();
				if ("xml:space".equals(name)) {
					continue; // XML built-in, handled by the loader
				}
				AttrSpec as = spec.attr(name);
				if (as == null) {
					errors.add(sources.locate(node) + ": <" + spec.name + "> has no attribute '"
							+ name + "' (known: " + spec.attrNames() + ")");
					continue;
				}
				if (as.type == ElementSpec.AttrType.INT
						|| as.type == ElementSpec.AttrType.INT_AUTO) {
					try {
						if (!(as.type == ElementSpec.AttrType.INT_AUTO
								&& "auto".equals(attr.getValue()))) {
							Values.parseInt((String) attr.getValue());
						}
					} catch (NumberFormatException e) {
						errors.add(sources.locate(node) + ": <" + spec.name + "> attribute '" + name
								+ "': '" + attr.getValue() + "' is not a number (decimal, 0x or $)"
								+ (as.type == ElementSpec.AttrType.INT_AUTO ? " nor \"auto\"" : ""));
					}
				} else if (as.type == ElementSpec.AttrType.BOOL) {
					String v = (String) attr.getValue();
					if (!"true".equalsIgnoreCase(v) && !"false".equalsIgnoreCase(v)) {
						errors.add(sources.locate(node) + ": <" + spec.name + "> attribute '" + name
								+ "': '" + v + "' is not true or false");
					}
				}
			}

			// a <default name="x.y"> must target a declared attribute, otherwise
			// the typo silently disables the default it meant to set
			if ("default".equals(spec.name)) {
				checkDefaultKey(node, sources, errors);
			}
		}

		for (ImmutableNode child : node.getChildren()) {
			walk(child, sources, errors);
		}
	}

	private static void checkDefaultKey(ImmutableNode node, SourceMap sources, List<String> errors) {
		String key = (String) node.getAttributes().get("name");
		if (key == null) {
			return; // the missing required attribute is reported by the handler
		}
		int dot = key.indexOf('.');
		if (dot <= 0) {
			errors.add(sources.locate(node) + ": <default> name '" + key
					+ "' must be <element>.<attribute>");
			return;
		}
		String element = key.substring(0, dot);
		String attribute = key.substring(dot + 1);

		ElementSpec target = Handlers.spec(element);
		if (target == null) {
			errors.add(sources.locate(node) + ": <default> targets unknown element '" + element + "'");
			return;
		}
		if (target.attr(attribute) == null) {
			errors.add(sources.locate(node) + ": <default> targets '" + key + "' but <" + element
					+ "> has no attribute '" + attribute + "' (known: " + target.attrNames() + ")");
		}
	}
}
