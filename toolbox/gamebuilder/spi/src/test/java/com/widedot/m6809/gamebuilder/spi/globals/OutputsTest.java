package com.widedot.m6809.gamebuilder.spi.globals;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.file.Files;
import java.nio.file.Path;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * A target that fails must not leave its images behind : they carry a fresh
 * timestamp and boot into garbage, which reads exactly like a good build.
 */
public class OutputsTest {

	@Test
	void discardRemovesEveryRecordedFile(@TempDir Path dist) throws Exception {
		Path fd = Files.createFile(dist.resolve("to8.fd"));
		Path sap = Files.createFile(dist.resolve("to8_0.sap"));

		Outputs outputs = new Outputs();
		outputs.record(fd);
		outputs.record(sap.toString());

		assertEquals(2, outputs.discard());
		assertFalse(Files.exists(fd));
		assertFalse(Files.exists(sap));
	}

	@Test
	void discardEmptiesTheRegisterSoASecondCallIsANoOp(@TempDir Path dist) throws Exception {
		outputsOf(Files.createFile(dist.resolve("to8.fd"))).discard();

		Outputs outputs = new Outputs();
		outputs.record(dist.resolve("to8.fd"));
		outputs.discard();
		assertEquals(0, outputs.discard());
		assertTrue(outputs.paths().isEmpty());
	}

	/**
	 * The build error that triggered the discard is what the author needs to
	 * read : a file already gone must not throw over it.
	 */
	@Test
	void aMissingFileDoesNotThrow(@TempDir Path dist) {
		Outputs outputs = new Outputs();
		outputs.record(dist.resolve("never-written.fd"));
		assertEquals(0, outputs.discard());
	}

	@Test
	void clearForgetsWithoutDeleting(@TempDir Path dist) throws Exception {
		Path fd = Files.createFile(dist.resolve("to8.fd"));
		Outputs outputs = new Outputs();
		outputs.record(fd);

		outputs.clear();

		assertTrue(outputs.paths().isEmpty());
		assertTrue(Files.exists(fd), "clear is for a new target, not a rollback");
	}

	private static Outputs outputsOf(Path path) {
		Outputs outputs = new Outputs();
		outputs.record(path);
		return outputs;
	}
}
