package com.widedot.m6809.gamebuilder.config;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

import com.widedot.m6809.gamebuilder.Handlers;
import com.widedot.m6809.gamebuilder.spi.schema.ElementSpec;
import com.widedot.m6809.gamebuilder.spi.schema.ElementSpec.AttrSpec;

/**
 * Generates an XML Schema from the element specs declared in {@link Handlers}.
 *
 * The specs are the single source of truth of the configuration format ; this
 * derives the editor-facing view of the same contract. A config declaring
 *
 *   xsi:noNamespaceSchemaLocation="path/to/gamebuilder.xsd"
 *
 * gets validation and attribute completion in any XML aware editor.
 *
 * The content model is deliberately permissive — any known element may appear
 * in any container, the per-container rules stay enforced by the build — but
 * attributes are strict and typed, which is where the mistakes actually
 * happen.
 */
public final class SchemaGenerator {

	private SchemaGenerator() {
	}

	public static String generate() {
		StringBuilder out = new StringBuilder();
		out.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
		out.append("<!-- Generated from the element specs in Handlers.java ; do not edit. -->\n");
		out.append("<xs:schema xmlns:xs=\"http://www.w3.org/2001/XMLSchema\">\n\n");

		// integer notation of the 6809 world : decimal, 0x, $
		out.append("  <xs:simpleType name=\"int6809\">\n");
		out.append("    <xs:restriction base=\"xs:string\">\n");
		out.append("      <xs:pattern value=\"-?([0-9]+|0[xX][0-9a-fA-F]+|\\$[0-9a-fA-F]+)\"/>\n");
		out.append("    </xs:restriction>\n");
		out.append("  </xs:simpleType>\n\n");

		List<ElementSpec> specs = new ArrayList<ElementSpec>(Handlers.specs());
		specs.sort(Comparator.comparing(s -> s.name));

		for (ElementSpec spec : specs) {
			if (!spec.getDoc().isEmpty()) {
				out.append("  <!-- ").append(spec.getDoc()).append(" -->\n");
			}
			out.append("  <xs:element name=\"").append(spec.name).append("\">\n");
			out.append("    <xs:complexType");
			if (spec.allowsText()) {
				out.append(" mixed=\"true\"");
			}
			out.append(">\n");
			boolean wantsXmlSpace = spec.allowsText();

			// permissive content : any known element, the build enforces the rest
			out.append("      <xs:choice minOccurs=\"0\" maxOccurs=\"unbounded\">\n");
			for (ElementSpec child : specs) {
				out.append("        <xs:element ref=\"").append(child.name).append("\"/>\n");
			}
			out.append("      </xs:choice>\n");

			for (AttrSpec attr : spec.attrs()) {
				out.append("      <xs:attribute name=\"").append(attr.name).append("\"");
				out.append(" type=\"").append(xsdType(attr)).append("\"");
				if (attr.required) {
					out.append(" use=\"required\"");
				}
				if (attr.doc != null && !attr.doc.isEmpty()) {
					out.append(">\n");
					out.append("        <xs:annotation><xs:documentation>")
					   .append(escape(attr.doc))
					   .append("</xs:documentation></xs:annotation>\n");
					out.append("      </xs:attribute>\n");
				} else {
					out.append("/>\n");
				}
			}
			if (wantsXmlSpace) {
				// admits xml:space without importing the XML namespace schema,
				// which validators cannot fetch offline
				out.append("      <xs:anyAttribute namespace=\"http://www.w3.org/XML/1998/namespace\""
						+ " processContents=\"skip\"/>\n");
			}
			out.append("    </xs:complexType>\n");
			out.append("  </xs:element>\n\n");
		}

		out.append("</xs:schema>\n");
		return out.toString();
	}

	private static String xsdType(AttrSpec attr) {
		switch (attr.type) {
			case INT: return "int6809";
			case BOOL: return "xs:boolean";
			default: return "xs:string";
		}
	}

	private static String escape(String s) {
		return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
	}
}
