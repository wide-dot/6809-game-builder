package com.widedot.m6809.gamebuilder.config;

import static org.junit.jupiter.api.Assertions.*;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import org.apache.commons.configuration2.tree.ImmutableNode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class XmlLoaderTest {

	@TempDir
	Path dir;

	private XmlLoader.Result load(String xml) throws Exception {
		Path f = dir.resolve("test.config.xml");
		Files.write(f, xml.getBytes(StandardCharsets.UTF_8));
		return XmlLoader.load(f.toFile());
	}

	@Test
	@DisplayName("structure : names, attributes, child order are preserved")
	void structure() throws Exception {
		XmlLoader.Result r = load(
			"<configuration>\n" +
			"  <target name=\"fd\">\n" +
			"    <bin filename=\"a.bin\"/>\n" +
			"    <lwasm format=\"obj\"/>\n" +
			"    <bin filename=\"b.bin\"/>\n" +
			"  </target>\n" +
			"</configuration>\n");

		assertEquals("configuration", r.root.getNodeName());
		ImmutableNode target = r.root.getChildren().get(0);
		assertEquals("fd", target.getAttributes().get("name"));

		// heterogeneous child order is what file ids and memory layout hang on
		assertEquals("bin", target.getChildren().get(0).getNodeName());
		assertEquals("lwasm", target.getChildren().get(1).getNodeName());
		assertEquals("bin", target.getChildren().get(2).getNodeName());
		assertEquals("b.bin", target.getChildren().get(2).getAttributes().get("filename"));
	}

	@Test
	@DisplayName("text is trimmed by default, whitespace-only text is dropped")
	void trimming() throws Exception {
		XmlLoader.Result r = load(
			"<configuration>\n" +
			"  <asm>  loader.PAGE equ 4  </asm>\n" +
			"  <empty>   </empty>\n" +
			"</configuration>\n");

		assertEquals("loader.PAGE equ 4", r.root.getChildren().get(0).getValue());
		assertNull(r.root.getChildren().get(1).getValue());
	}

	@Test
	@DisplayName("xml:space=preserve keeps leading whitespace, inline asm relies on it")
	void preserve() throws Exception {
		XmlLoader.Result r = load(
			"<configuration>\n" +
			"  <asm xml:space=\"preserve\">        org   $2100</asm>\n" +
			"</configuration>\n");

		// a trimmed "org" would become a label instead of an opcode
		assertEquals("        org   $2100", r.root.getChildren().get(0).getValue());
	}

	@Test
	@DisplayName("every element knows its file and line")
	void locations() throws Exception {
		XmlLoader.Result r = load(
			"<configuration>\n" +
			"  <target name=\"fd\">\n" +
			"    <direntry name=\"x\"/>\n" +
			"  </target>\n" +
			"</configuration>\n");

		ImmutableNode direntry = r.root.getChildren().get(0).getChildren().get(0);
		assertEquals("test.config.xml:3", r.sources.locate(direntry));
	}

	@Test
	@DisplayName("malformed XML fails with the file and line in the message")
	void malformed() throws Exception {
		Exception e = assertThrows(Exception.class,
				() -> load("<configuration>\n  <target>\n</configuration>\n"));
		assertTrue(e.getMessage().contains("test.config.xml:3"),
				"got: " + e.getMessage());
	}

	@Test
	@DisplayName("no interpolation : a ${...} value arrives verbatim")
	void noInterpolation() throws Exception {
		XmlLoader.Result r = load(
			"<configuration><define symbol=\"x\" value=\"${oops}\"/></configuration>");
		assertEquals("${oops}", r.root.getChildren().get(0).getAttributes().get("value"));
	}

	@Test
	@DisplayName("external entities are refused")
	void noExternalEntities() throws Exception {
		File secret = dir.resolve("secret.txt").toFile();
		Files.write(secret.toPath(), "boo".getBytes(StandardCharsets.UTF_8));
		assertThrows(Exception.class, () -> load(
			"<?xml version=\"1.0\"?>\n" +
			"<!DOCTYPE configuration [<!ENTITY x SYSTEM \"" + secret.toURI() + "\">]>\n" +
			"<configuration><asm>&x;</asm></configuration>"));
	}
}
