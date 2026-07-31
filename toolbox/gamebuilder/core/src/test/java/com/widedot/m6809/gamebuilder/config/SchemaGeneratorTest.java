package com.widedot.m6809.gamebuilder.config;

import static org.junit.jupiter.api.Assertions.*;

import java.io.StringReader;

import javax.xml.XMLConstants;
import javax.xml.transform.stream.StreamSource;
import javax.xml.validation.SchemaFactory;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.xml.sax.SAXException;

class SchemaGeneratorTest {

	private static javax.xml.validation.Validator schemaValidator() throws Exception {
		String xsd = SchemaGenerator.generate();
		SchemaFactory f = SchemaFactory.newInstance(XMLConstants.W3C_XML_SCHEMA_NS_URI);
		return f.newSchema(new StreamSource(new StringReader(xsd))).newValidator();
	}

	@Test
	@DisplayName("the generated schema is itself a valid XSD")
	void schemaIsWellFormed() throws Exception {
		assertNotNull(schemaValidator());
	}

	@Test
	@DisplayName("a representative configuration validates")
	void representativeConfigValidates() throws Exception {
		String config =
			"<configuration><target name=\"fd\">\n" +
			"  <floppydisk model=\"fd640\" storage=\"engine/config/storage.xml\">\n" +
			"    <section name=\"DATA\" track=\"1\" face=\"0\" sector=\"1\"/>\n" +
			"    <define symbol=\"loader.ADDRESS\" value=\"$A000\"/>\n" +
			"    <directory id=\"0\" section=\"INDEX\" gensymbols=\"gen/entries.asm\">\n" +
			"      <default name=\"direntry.maxsize\" value=\"0x4000\"/>\n" +
			"      <direntry name=\"x\" codec=\"zx0\" loadtimelink=\"LINK\">\n" +
			"        <bin filename=\"a.bin\"/>\n" +
			"        <lwasm gensource=\"gen/x.asm\">\n" +
			"          <asm xml:space=\"preserve\">        org   $2100</asm>\n" +
			"          <label name=\"sym\"/>\n" +
			"        </lwasm>\n" +
			"      </direntry>\n" +
			"    </directory>\n" +
			"    <fd filename=\"out.fd\"/>\n" +
			"  </floppydisk>\n" +
			"</target></configuration>";
		schemaValidator().validate(new StreamSource(new StringReader(config)));
	}

	@Test
	@DisplayName("an unknown attribute is rejected by the schema too")
	void unknownAttributeRejected() throws Exception {
		String config = "<configuration><target name=\"fd\">"
				+ "<direntry name=\"x\" codek=\"zx0\"/></target></configuration>";
		assertThrows(SAXException.class,
				() -> schemaValidator().validate(new StreamSource(new StringReader(config))));
	}

	@Test
	@DisplayName("a malformed hex value is rejected by the schema too")
	void badHexRejected() throws Exception {
		String config = "<configuration><target name=\"fd\">"
				+ "<direntry name=\"x\" maxsize=\"beaucoup\"/></target></configuration>";
		assertThrows(SAXException.class,
				() -> schemaValidator().validate(new StreamSource(new StringReader(config))));
	}
}
