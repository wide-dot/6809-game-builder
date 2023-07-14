package com.widedot.m6809.gamebuilder.plugin.lwasm.util;

import java.io.File;
import java.io.IOException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Optional;

public class FileUtil {

	public static String removeExtension(String filename) {
		int extensionIndex = filename.lastIndexOf(".");
		return (extensionIndex < 0) ? filename : filename.substring(0, extensionIndex);
	}
	
	public static Optional<String> getExtension(String filename) {
		return Optional.ofNullable(filename).filter(f -> f.contains("."))
				.map(f -> f.substring(filename.lastIndexOf(".") + 1));
	}
	
	public static String getBasename(String filename) {
		return Paths.get(filename).toAbsolutePath().normalize().getFileName().toString().replace('\\', '/') + "/";
	}

	public static String getDir(File file) throws IOException {
		return Paths.get(file.getCanonicalPath()).toAbsolutePath().normalize().getParent().toString().replace('\\', '/') + "/";
	}

	public static String getDir(Path path) throws IOException {
		return path.toAbsolutePath().normalize().getParent().toString().replace('\\', '/') + "/";
	}
	
	public static String getDir(String filename) throws IOException {
		return Paths.get(filename).toAbsolutePath().normalize().getParent().toString().replace('\\', '/') + "/";
	}

}