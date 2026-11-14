package com.widedot.toolbox.graphics.raycast;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

/** the views the tests share */
final class Views {

	private Views() {
	}

	/** the whole screen, the default settings */
	static Geometry whole() {
		return new Geometry(80, 200, 0, 0, 2, 8, 440, 66, 0.75);
	}

	/** a smaller view, away from the screen's corner */
	static Geometry small() {
		return new Geometry(64, 128, 8, 36, 2, 8, 280, 66, 0.75);
	}

	/** the small view, a texel a row, a wider field, taller walls */
	static Geometry fine() {
		return new Geometry(64, 128, 8, 36, 1, 4, 280, 90, 1.0);
	}

	/** the repository's root, or null */
	static Path root() {
		Path root = Paths.get("").toAbsolutePath();
		while (root != null && !Files.isDirectory(root.resolve("toolbox/third-party"))) {
			root = root.getParent();
		}
		return root;
	}
}
