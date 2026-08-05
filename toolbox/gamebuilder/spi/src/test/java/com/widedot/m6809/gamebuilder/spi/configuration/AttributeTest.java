package com.widedot.m6809.gamebuilder.spi.configuration;

import static org.junit.jupiter.api.Assertions.*;

import java.util.Map;

import org.apache.commons.configuration2.tree.ImmutableNode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * Attribute resolves a value in three steps : the attribute carried by the XML
 * node, then the inherited defaults under the fully qualified key, then the
 * hardcoded fallback. Getting that cascade wrong silently changes the meaning
 * of a whole configuration, so it is pinned here.
 */
class AttributeTest {

	private static ImmutableNode node(String name, Map<String, Object> attrs) {
		ImmutableNode.Builder b = new ImmutableNode.Builder().name(name);
		attrs.forEach(b::addAttribute);
		return b.create();
	}

	@Test
	@DisplayName("the node attribute wins over defaults and fallback")
	void nodeAttributeWins() throws Exception {
		ImmutableNode n = node("file", Map.of("codec", "zx0"));
		Defaults d = new Defaults();
		d.values.put("file.codec", "exomizer");

		assertEquals("zx0", Attribute.getString(n, d, "codec", "file.codec", "none"));
	}

	@Test
	@DisplayName("defaults are used when the node carries nothing")
	void defaultsAreUsed() throws Exception {
		ImmutableNode n = node("file", Map.of());
		Defaults d = new Defaults();
		d.values.put("file.codec", "exomizer");

		assertEquals("exomizer", Attribute.getString(n, d, "codec", "file.codec", "none"));
	}

	@Test
	@DisplayName("the fallback is used when neither node nor defaults match")
	void fallbackIsUsed() throws Exception {
		ImmutableNode n = node("file", Map.of());
		Defaults d = new Defaults();

		assertEquals("none", Attribute.getString(n, d, "codec", "file.codec", "none"));
	}

	@Test
	@DisplayName("defaults are keyed by the fully qualified name, not the short one")
	void defaultsAreKeyedByFullName() throws Exception {
		ImmutableNode n = node("file", Map.of());
		Defaults d = new Defaults();
		// a default declared under the wrong namespace must not be picked up
		d.values.put("codec", "exomizer");

		assertEquals("none", Attribute.getString(n, d, "codec", "file.codec", "none"));
	}

	@Test
	@DisplayName("a mandatory attribute that resolves to nothing fails the build")
	void mandatoryMissingThrows() {
		ImmutableNode n = node("fd", Map.of());
		Exception e = assertThrows(Exception.class,
				() -> Attribute.getString(n, new Defaults(), "filename", "fd.filename"));
		assertTrue(e.getMessage().contains("fd.filename"),
				"the message must name the missing attribute, got: " + e.getMessage());
	}

	@Test
	@DisplayName("an optional attribute that resolves to nothing yields null")
	void optionalMissingIsNull() throws Exception {
		ImmutableNode n = node("file", Map.of());
		assertNull(Attribute.getStringOpt(n, new Defaults(), "codec", "file.codec"));
	}

	@Test
	@DisplayName("integers accept decimal and 0x notations")
	void integerNotations() throws Exception {
		Defaults d = new Defaults();
		assertEquals(16384, Attribute.getInteger(node("e", Map.of("maxsize", "0x4000")), d,
				"maxsize", "file.maxsize", null));
		assertEquals(4, Attribute.getInteger(node("e", Map.of("page", "4")), d,
				"page", "x.page", null));
	}

	@Test
	@DisplayName("an integer falls back to its default value")
	void integerFallback() throws Exception {
		assertEquals(42, Attribute.getInteger(node("e", Map.of()), new Defaults(),
				"maxsize", "file.maxsize", 42));
	}
}
