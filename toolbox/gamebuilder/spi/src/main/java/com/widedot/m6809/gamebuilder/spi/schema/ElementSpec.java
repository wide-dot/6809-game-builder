package com.widedot.m6809.gamebuilder.spi.schema;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Declared shape of one configuration element : its attributes, their types,
 * whether they are required, and their documentation.
 *
 * This is the attribute contract. Until now the only definition of the
 * configuration format was the set of Attribute.get calls scattered through
 * the handlers — which is why a typo in an attribute name was silently
 * ignored, and why a defaults key could drift from the element that read it
 * (the 16 KB direntry guard stayed inactive for years that way). A declared
 * spec is validated before the build runs, derives the defaults namespace
 * mechanically, and doubles as the reference documentation and the source of
 * the generated XSD.
 */
public final class ElementSpec {

	public enum AttrType {
		/** free text */
		STRING,
		/** decimal, 0x or $ notation */
		INT,
		/** true or false */
		BOOL
	}

	public static final class AttrSpec {
		public final String name;
		public final AttrType type;
		public final boolean required;
		public final String doc;

		AttrSpec(String name, AttrType type, boolean required, String doc) {
			this.name = name;
			this.type = type;
			this.required = required;
			this.doc = doc;
		}
	}

	public final String name;
	private String doc = "";
	private boolean allowsText = false;
	private final List<AttrSpec> attrs = new ArrayList<AttrSpec>();

	private ElementSpec(String name) {
		this.name = name;
	}

	public static ElementSpec element(String name) {
		return new ElementSpec(name);
	}

	public ElementSpec doc(String text) {
		this.doc = text;
		return this;
	}

	/** the element may carry text content (inline assembly) */
	public ElementSpec text() {
		this.allowsText = true;
		return this;
	}

	public ElementSpec req(String attr, AttrType type, String doc) {
		attrs.add(new AttrSpec(attr, type, true, doc));
		return this;
	}

	public ElementSpec opt(String attr, AttrType type, String doc) {
		attrs.add(new AttrSpec(attr, type, false, doc));
		return this;
	}

	public String getDoc() {
		return doc;
	}

	public boolean allowsText() {
		return allowsText;
	}

	public List<AttrSpec> attrs() {
		return attrs;
	}

	public AttrSpec attr(String name) {
		for (AttrSpec a : attrs) {
			if (a.name.equals(name)) {
				return a;
			}
		}
		return null;
	}

	public String attrNames() {
		return attrs.stream().map(a -> a.name).collect(Collectors.joining(", "));
	}
}
