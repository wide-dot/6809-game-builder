package com.widedot.m6809.gamebuilder.spi.globals;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import lombok.extern.slf4j.Slf4j;

/**
 * The distributable files a target writes — the disk and cartridge images.
 *
 * They are written as the target runs, well before the checks that close it
 * (interface regions, dangling imports). A target that fails those checks would
 * otherwise leave a freshly timestamped image in {@code dist/} that is
 * indistinguishable from a good one and boots into garbage : measured, and it
 * cost a debugging session. Registering them here lets the target delete what
 * it produced when it refuses the build.
 *
 * Deleting rather than keeping is the deliberate choice : a build that failed
 * produced nothing, and an absent file says so in a way a stale one cannot.
 */
@Slf4j
public class Outputs {

	private final List<Path> paths = new ArrayList<Path>();

	public void record(Path path) {
		if (path != null) paths.add(path);
	}

	public void record(String path) {
		if (path != null) paths.add(Paths.get(path));
	}

	public List<Path> paths() {
		return Collections.unmodifiableList(paths);
	}

	public void clear() {
		paths.clear();
	}

	/**
	 * Deletes every file the target wrote. Best effort : a file already gone,
	 * or held by something else, must not mask the build error that got us
	 * here.
	 *
	 * @return how many were removed
	 */
	public int discard() {
		int removed = 0;
		for (Path path : paths) {
			try {
				if (Files.deleteIfExists(path)) {
					removed++;
					log.info("removed {} : the target did not complete", path);
				}
			} catch (Exception e) {
				log.warn("could not remove {} : {}", path, e.getMessage());
			}
		}
		paths.clear();
		return removed;
	}
}
