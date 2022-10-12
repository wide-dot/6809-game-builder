package com.widedot.m6809.gamebuilder.util;

import java.io.File;
import java.io.IOException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Optional;

public class FileUtil {
	
	public static String removeExtension(String filename) {

		// Remove the extension.
		int extensionIndex = filename.lastIndexOf(".");
        return (extensionIndex < 0 ) ? filename :filename.substring(0, extensionIndex);				

	}
	
	public static String basename(String filename) {

        if (filename == null)
            return "";

        String basename = filename;
        int idx = basename.lastIndexOf('/');
        if (idx >= 0) {
            idx++;
            if (basename.length() == idx)
                return "";
            else
                basename = basename.substring(idx);
        }
        idx = basename.lastIndexOf('\\');
        if (idx >= 0) {
            idx++;
            if (basename.length() == idx)
                return "";
            else
                basename = basename.substring(idx);
        }
        return basename.trim();
    }
	
	public static Optional<String> getExtensionByStringHandling(String filename) {
	    return Optional.ofNullable(filename)
	      .filter(f -> f.contains("."))
	      .map(f -> f.substring(filename.lastIndexOf(".") + 1));
	}	
	
	public static String getParentDir(File file) throws IOException {
		return Paths.get(file.getCanonicalPath()).toAbsolutePath().getParent().toString().replace('\\', '/')+"/";
	}
	
	public static String getParentDir(Path path) throws IOException {
		return path.toAbsolutePath().getParent().toString().replace('\\', '/')+"/";
	}

}