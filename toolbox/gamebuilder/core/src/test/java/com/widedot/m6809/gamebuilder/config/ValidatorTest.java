package com.widedot.m6809.gamebuilder.config;

import static org.junit.jupiter.api.Assertions.*;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import com.widedot.m6809.gamebuilder.spi.configuration.Values;

class ValidatorTest {

	@TempDir
	Path dir;

	private Exception check(String xml) throws Exception {
		Path f = dir.resolve("t.config.xml");
		Files.write(f, xml.getBytes(StandardCharsets.UTF_8));
		XmlLoader.Result r = XmlLoader.load(f.toFile());
		try {
			Validator.validate(r.root, r.sources);
			return null;
		} catch (Exception e) {
			return e;
		}
	}

	@Test
	@DisplayName("a valid tree passes")
	void validTree() throws Exception {
		assertNull(check(
			"<configuration><target name=\"fd\">\n" +
			"  <file name=\"x\" codec=\"zx0\" maxsize=\"0x4000\"/>\n" +
			"</target></configuration>"));
	}

	@Test
	@DisplayName("a typo in an attribute name is an error naming the candidates")
	void unknownAttribute() throws Exception {
		Exception e = check(
			"<configuration><target name=\"fd\">\n" +
			"  <file name=\"x\" codek=\"zx0\"/>\n" +
			"</target></configuration>");
		assertNotNull(e, "a typo used to be silently ignored");
		assertTrue(e.getMessage().contains("t.config.xml:2"), e.getMessage());
		assertTrue(e.getMessage().contains("codek"), e.getMessage());
		assertTrue(e.getMessage().contains("codec"), "candidates must be listed: " + e.getMessage());
	}

	@Test
	@DisplayName("all errors are reported at once")
	void allErrorsAtOnce() throws Exception {
		Exception e = check(
			"<configuration><target name=\"fd\">\n" +
			"  <file name=\"x\" codek=\"zx0\"/>\n" +
			"  <file name=\"y\" maxsize=\"beaucoup\"/>\n" +
			"</target></configuration>");
		assertNotNull(e);
		assertTrue(e.getMessage().contains("codek"), e.getMessage());
		assertTrue(e.getMessage().contains("beaucoup"), e.getMessage());
	}

	@Test
	@DisplayName("a default targeting a foreign or misspelled key is an error")
	void defaultKeyChecked() throws Exception {
		Exception e = check(
			"<configuration><target name=\"fd\">\n" +
			"  <default name=\"file.maxsze\" value=\"0x4000\"/>\n" +
			"</target></configuration>");
		assertNotNull(e, "the 16 KB guard stayed inactive on exactly this class of typo");
		assertTrue(e.getMessage().contains("maxsze"), e.getMessage());

		assertNull(check(
			"<configuration><target name=\"fd\">\n" +
			"  <default name=\"file.maxsize\" value=\"0x4000\"/>\n" +
			"</target></configuration>"));
	}

	@Test
	@DisplayName("integer notations: decimal, 0x, $, and no octal trap")
	void intNotations() {
		assertEquals(16384, Values.parseInt("0x4000"));
		assertEquals(0xA000, Values.parseInt("$A000"));
		assertEquals(16, Values.parseInt("16"));
		// Integer.decode would have read this as octal 8
		assertEquals(10, Values.parseInt("010"));
		assertEquals(-4, Values.parseInt("-4"));
		assertNull(Values.parseInt(null));
		assertThrows(NumberFormatException.class, () -> Values.parseInt("beaucoup"));
	}
}
