package com.widedot.m6809.util;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.file.Files;
import java.nio.file.Path;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class ThirdPartyToolsTest {

	@Test
	void explicitPropertyWins(@TempDir Path tmp) throws Exception {
		Path exe = Files.createFile(tmp.resolve("elsewhere"));
		exe.toFile().setExecutable(true);
		System.setProperty("faketool.path", exe.toString());
		try {
			assertEquals(exe.toString(), ThirdPartyTools.resolve("faketool"));
		} finally {
			System.clearProperty("faketool.path");
		}
	}

	@Test
	void shippedBinaryIsFoundUnderBasedir(@TempDir Path tmp) throws Exception {
		// disposition d'un exemplaire de travail : toolbox/third-party/bin/<os>/
		String os = System.getProperty("os.name").toLowerCase().contains("mac") ? "macos"
				: System.getProperty("os.name").toLowerCase().contains("win") ? "win" : "linux";
		Path dir = Files.createDirectories(tmp.resolve("toolbox/third-party/bin/" + os));
		Path exe = Files.createFile(dir.resolve(ThirdPartyTools.executableName("faketool")));
		exe.toFile().setExecutable(true);

		String previous = System.getProperty("basedir");
		System.setProperty("basedir", tmp.toString());
		try {
			assertEquals(exe.toString(), ThirdPartyTools.resolve("faketool"));
		} finally {
			if (previous == null) System.clearProperty("basedir");
			else System.setProperty("basedir", previous);
		}
	}

	@Test
	void distributionLayoutIsFoundToo(@TempDir Path tmp) throws Exception {
		Path dir = Files.createDirectories(tmp.resolve("bin"));
		Path exe = Files.createFile(dir.resolve(ThirdPartyTools.executableName("faketool")));
		exe.toFile().setExecutable(true);

		String previous = System.getProperty("basedir");
		System.setProperty("basedir", tmp.toString());
		try {
			assertEquals(exe.toString(), ThirdPartyTools.resolve("faketool"));
		} finally {
			if (previous == null) System.clearProperty("basedir");
			else System.setProperty("basedir", previous);
		}
	}

	@Test
	void fallsBackToThePlatformNameForThePath(@TempDir Path tmp) {
		String previous = System.getProperty("basedir");
		System.setProperty("basedir", tmp.toString());   // vide : rien à trouver
		try {
			// jamais "lwasm.exe" ailleurs que sous Windows — c'est le défaut qui
			// imposait un shim aux utilisateurs macOS et Linux.
			assertEquals(ThirdPartyTools.executableName("lwasm"), ThirdPartyTools.resolve("lwasm"));
			assertTrue(OSValidator.IS_WINDOWS == ThirdPartyTools.resolve("lwasm").endsWith(".exe"));
		} finally {
			if (previous == null) System.clearProperty("basedir");
			else System.setProperty("basedir", previous);
		}
	}
}
