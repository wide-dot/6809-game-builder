package com.widedot.m6809.gamebuilder.config;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.util.ArrayDeque;
import java.util.Deque;

import javax.xml.stream.Location;
import javax.xml.stream.XMLInputFactory;
import javax.xml.stream.XMLStreamConstants;
import javax.xml.stream.XMLStreamException;
import javax.xml.stream.XMLStreamReader;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.configuration.SourceMap;

/**
 * Loads a configuration file into an ImmutableNode tree, keeping the source
 * position of every element in a {@link SourceMap}.
 *
 * This replaces commons-configuration2's XMLConfiguration for loading. That
 * class is a settings library pressed into service as a document parser: it
 * discards source positions, so no error could ever say where in the file it
 * happened, and it wires up ${...} interpolation nobody asked for. The tree
 * type stays ImmutableNode because every handler consumes it; only the way it
 * is built changes.
 *
 * Text handling matches the previous loader: whitespace-only content is
 * dropped, values are trimmed, except under xml:space="preserve" (inherited,
 * per the XML spec) where the text is kept verbatim — inline assembly relies
 * on its leading spaces.
 */
public final class XmlLoader {

	private XmlLoader() {
	}

	public static class Result {
		public final ImmutableNode root;
		public final SourceMap sources;

		Result(ImmutableNode root, SourceMap sources) {
			this.root = root;
			this.sources = sources;
		}
	}

	public static Result load(File file) throws Exception {
		XMLInputFactory factory = XMLInputFactory.newFactory();
		// configuration files have no business loading DTDs or external entities
		factory.setProperty(XMLInputFactory.SUPPORT_DTD, false);
		factory.setProperty(XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES, false);

		SourceMap sources = new SourceMap(file.getName());

		try (InputStream in = new FileInputStream(file)) {
			XMLStreamReader reader = factory.createXMLStreamReader(in);
			try {
				return new Result(parse(reader, sources, file), sources);
			} finally {
				reader.close();
			}
		} catch (XMLStreamException e) {
			Location l = e.getLocation();
			String at = l == null ? file.getName() : file.getName() + ":" + l.getLineNumber();
			throw new Exception("Malformed XML at " + at + ": " + e.getMessage(), e);
		}
	}

	/** one element being built */
	private static final class Frame {
		final ImmutableNode.Builder builder = new ImmutableNode.Builder();
		final StringBuilder text = new StringBuilder();
		final boolean preserve;
		final int line;
		final int column;

		Frame(boolean preserve, int line, int column) {
			this.preserve = preserve;
			this.line = line;
			this.column = column;
		}
	}

	private static ImmutableNode parse(XMLStreamReader reader, SourceMap sources, File file) throws Exception {
		Deque<Frame> stack = new ArrayDeque<Frame>();
		ImmutableNode root = null;

		while (reader.hasNext()) {
			switch (reader.next()) {

			case XMLStreamConstants.START_ELEMENT: {
				boolean parentPreserve = !stack.isEmpty() && stack.peek().preserve;
				boolean preserve = parentPreserve;

				Location loc = reader.getLocation();
				Frame frame = null; // created after xml:space is known

				String name = reader.getLocalName();
				int attrCount = reader.getAttributeCount();

				// xml:space wins over inheritance
				for (int i = 0; i < attrCount; i++) {
					if ("space".equals(reader.getAttributeLocalName(i))
							&& "xml".equals(reader.getAttributePrefix(i))) {
						preserve = "preserve".equals(reader.getAttributeValue(i));
					}
				}

				frame = new Frame(preserve, loc.getLineNumber(), loc.getColumnNumber());
				frame.builder.name(name);
				for (int i = 0; i < attrCount; i++) {
					String prefix = reader.getAttributePrefix(i);
					String attrName = (prefix == null || prefix.isEmpty())
							? reader.getAttributeLocalName(i)
							: prefix + ":" + reader.getAttributeLocalName(i);
					frame.builder.addAttribute(attrName, reader.getAttributeValue(i));
				}
				stack.push(frame);
				break;
			}

			case XMLStreamConstants.CHARACTERS:
			case XMLStreamConstants.CDATA:
				if (!stack.isEmpty()) {
					stack.peek().text.append(reader.getText());
				}
				break;

			case XMLStreamConstants.END_ELEMENT: {
				Frame frame = stack.pop();

				String text = frame.text.toString();
				if (!frame.preserve) {
					text = text.trim();
				}
				if (!text.isEmpty()) {
					frame.builder.value(text);
				}

				ImmutableNode node = frame.builder.create();
				sources.put(node, frame.line, frame.column);

				if (stack.isEmpty()) {
					root = node;
				} else {
					stack.peek().builder.addChild(node);
				}
				break;
			}

			default:
				// comments, processing instructions, whitespace events: ignored
			}
		}

		if (root == null) {
			throw new Exception("Empty configuration file: " + file.getName());
		}
		return root;
	}

}
