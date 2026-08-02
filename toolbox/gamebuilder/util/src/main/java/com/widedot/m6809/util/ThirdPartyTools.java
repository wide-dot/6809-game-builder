package com.widedot.m6809.util;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Resolves the third-party executables the build shells out to (lwasm, lwlink,
 * exomizer, hxcfe...).
 *
 * <p>The repository ships these binaries per platform under
 * {@code toolbox/third-party/bin/<os>/}, and the distribution lays them next to
 * its launcher in {@code <basedir>/bin/}. Neither is on the PATH, so naming a
 * bare executable and hoping — worse, naming a Windows {@code .exe} on every
 * platform — is how a build ends up demanding that its user create a shim.
 *
 * <p>Resolution order, first hit wins :
 * <ol>
 *   <li>{@code -D<name>.path=/full/path} — explicit override, always wins ;</li>
 *   <li>the {@code <NAME>} environment variable, same purpose ;</li>
 *   <li>{@code <basedir>/toolbox/third-party/bin/<os>/<exe>} — a working copy ;</li>
 *   <li>{@code <basedir>/bin/<exe>} — an unpacked distribution ;</li>
 *   <li>the bare executable name, left to the PATH.</li>
 * </ol>
 */
public final class ThirdPartyTools {

	private ThirdPartyTools() {}

	/**
	 * @param name tool name without extension, e.g. {@code "lwasm"}
	 * @return an absolute path when the tool ships with the build, otherwise the
	 *         platform executable name for the PATH to resolve
	 */
	public static String resolve(String name) {
		String override = System.getProperty(name + ".path");
		if (override == null || override.isBlank()) {
			override = System.getenv(name.toUpperCase());
		}
		if (override != null && !override.isBlank()) {
			return override;
		}

		String exe = executableName(name);
		String basedir = System.getProperty("basedir");
		if (basedir != null && !basedir.isBlank()) {
			Path shipped = Paths.get(basedir, "toolbox", "third-party", "bin", platformDir(), exe);
			if (isExecutable(shipped)) {
				return shipped.toString();
			}
			Path distributed = Paths.get(basedir, "bin", exe);
			if (isExecutable(distributed)) {
				return distributed.toString();
			}
		}
		return exe;
	}

	/** Windows is the only platform that wants the {@code .exe} suffix. */
	public static String executableName(String name) {
		return OSValidator.IS_WINDOWS ? name + ".exe" : name;
	}

	/** Directory name under {@code third-party/bin}, matching the packaging descriptors. */
	private static String platformDir() {
		if (OSValidator.IS_WINDOWS) return "win";
		if (OSValidator.IS_MAC) return "macos";
		String arch = System.getProperty("os.arch", "").toLowerCase();
		// os.arch, not os.name : OSValidator.IS_ARM reads the OS name, which never
		// carries the architecture on Linux.
		return (arch.startsWith("arm") || arch.startsWith("aarch64")) ? "linux-arm" : "linux";
	}

	private static boolean isExecutable(Path p) {
		File f = p.toFile();
		return Files.isRegularFile(p) && f.canExecute();
	}
}
