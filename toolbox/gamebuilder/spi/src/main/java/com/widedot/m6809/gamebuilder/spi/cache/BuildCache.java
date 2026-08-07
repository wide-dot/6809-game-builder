package com.widedot.m6809.gamebuilder.spi.cache;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.MessageDigest;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import lombok.extern.slf4j.Slf4j;

/**
 * The one build cache, shared by every plugin that pays for a pure function.
 *
 * Three plugins learned the same lesson separately — gfxcomp's encoders, the
 * lwasm spawns and the zx0 compressor are pure functions of what they can see,
 * repeated between the discovery pass and the real pass, then again at every
 * build of a working session. Each had grown its own dotdir, its own hashing,
 * its own atomic-store dance. This class is that pattern written once :
 *
 * <pre>
 * Entry e = BuildCache.entry("gfxcomp", CACHE_VERSION)
 *     .keyString(params).keyBytes(pixels);
 * Path hit = e.find();
 * if (hit != null) { ...copy from hit... }
 * else { ...produce... ; e.store(staging -> { ...copy outputs into staging... }); }
 * </pre>
 *
 * Everything lives under {@code <basedir>/.builder-cache/<domain>/<hash>/}.
 * One root : one .gitignore line, one directory to purge, one place for an
 * eviction policy the day the caches grow. {@code -Dbuilder.cache=off} turns
 * every domain off at once — the first thing to try when a build smells of a
 * stale entry. Hits and misses are counted per domain ; the main command
 * prints the tally at the end of the build.
 *
 * The store is atomic (staging directory renamed into place) and tolerant of
 * concurrent producers : whoever finishes second discards its copy, the
 * entries being equal by construction. A key always starts with the domain's
 * version constant — bump it when the producer's output changes, or the cache
 * would silently replay the old behaviour.
 */
@Slf4j
public final class BuildCache {

	/** hit/miss counters per domain, for the end-of-build tally */
	private static final Map<String, AtomicInteger[]> STATS = new ConcurrentHashMap<String, AtomicInteger[]>();

	private BuildCache() {
	}

	public static Entry entry(String domain, String version) throws Exception {
		return new Entry(domain, version);
	}

	/** null when caching is unavailable (no basedir) or disabled (builder.cache=off) */
	private static Path root() {
		if ("off".equals(System.getProperty("builder.cache"))) {
			return null;
		}
		String basedir = System.getProperty("basedir");
		return basedir == null ? null : Paths.get(basedir, ".builder-cache");
	}

	private static AtomicInteger[] counters(String domain) {
		return STATS.computeIfAbsent(domain,
				d -> new AtomicInteger[] { new AtomicInteger(), new AtomicInteger() });
	}

	/** one line per domain that saw traffic ; silent when caching never ran */
	public static void logSummary() {
		for (Map.Entry<String, AtomicInteger[]> e : STATS.entrySet()) {
			log.info("cache {} : {} hits, {} misses", e.getKey(),
					e.getValue()[0].get(), e.getValue()[1].get());
		}
	}

	@FunctionalInterface
	public interface Filler {
		/** copy the produced outputs into the staging directory */
		void fill(Path staging) throws Exception;
	}

	public static final class Entry {

		/**
		 * The include line of lwasm sources, reused by any domain whose input
		 * is a source tree : INCLUDE, includebin and use, quoted or not.
		 */
		private static final Pattern INCLUDE_LINE = Pattern.compile(
				"^\\s*(?:include|includebin|use)\\s+\"?([^\"\\s]+)\"?.*",
				Pattern.CASE_INSENSITIVE);

		private final String domain;
		private final MessageDigest md;

		private Entry(String domain, String version) throws Exception {
			this.domain = domain;
			this.md = MessageDigest.getInstance("SHA-256");
			keyString(version);
		}

		public Entry keyString(String s) {
			md.update(s.getBytes(StandardCharsets.UTF_8));
			md.update((byte) 0);
			return this;
		}

		public Entry keyBytes(byte[] b) {
			md.update(b);
			md.update((byte) 0);
			return this;
		}

		/**
		 * A source and every file reachable through its include lines,
		 * resolved the way lwasm resolves them : against the including file's
		 * directory, then the include dirs. An include that cannot be resolved
		 * is keyed as missing — if it was conditional the hash is
		 * over-approximated, never wrong.
		 */
		public Entry keyFileTree(Path source, List<Path> includeDirs) throws Exception {
			hashTree(source, includeDirs, new LinkedHashSet<Path>());
			return this;
		}

		private void hashTree(Path file, List<Path> includeDirs, Set<Path> seen) throws Exception {
			Path normalized = file.toAbsolutePath().normalize();
			if (!seen.add(normalized)) {
				return;
			}
			byte[] content = Files.readAllBytes(normalized);
			keyBytes(content);
			for (String line : new String(content, StandardCharsets.ISO_8859_1).split("\r?\n")) {
				Matcher m = INCLUDE_LINE.matcher(line);
				if (!m.matches()) {
					continue;
				}
				String ref = m.group(1);
				Path resolved = null;
				Path parent = normalized.getParent();
				if (parent != null && Files.isRegularFile(parent.resolve(ref))) {
					resolved = parent.resolve(ref).normalize();
				} else {
					for (Path base : includeDirs) {
						Path candidate = base.resolve(ref).normalize();
						if (Files.isRegularFile(candidate)) {
							resolved = candidate;
							break;
						}
					}
				}
				if (resolved == null) {
					keyString("missing:" + ref);
					continue;
				}
				hashTree(resolved, includeDirs, seen);
			}
		}

		private String hex;

		private Path dir() {
			Path root = root();
			if (root == null) {
				return null;
			}
			if (hex == null) {
				// digest() resets the MessageDigest : computed once, so that
				// the find() and the store() of one entry agree on the key
				StringBuilder out = new StringBuilder();
				for (byte b : md.digest()) {
					out.append(String.format("%02x", b));
				}
				hex = out.toString();
			}
			return root.resolve(domain).resolve(hex);
		}

		/** the cached entry's directory, or null on miss or when disabled */
		public Path find() {
			Path dir = dir();
			if (dir != null && Files.isDirectory(dir)) {
				counters(domain)[0].incrementAndGet();
				return dir;
			}
			return null;
		}

		/** run the filler against a staging directory, then publish it atomically */
		public void store(Filler filler) throws Exception {
			Path dir = dir();
			if (dir == null) {
				return;
			}
			counters(domain)[1].incrementAndGet();
			Path tmp = dir.resolveSibling(dir.getFileName() + ".tmp-" + Thread.currentThread().getId());
			Files.createDirectories(tmp);
			filler.fill(tmp);
			try {
				Files.move(tmp, dir, java.nio.file.StandardCopyOption.ATOMIC_MOVE);
			} catch (java.nio.file.FileAlreadyExistsException | java.nio.file.AccessDeniedException race) {
				// another producer finished the same key first : equal by construction
				try (java.util.stream.Stream<Path> entries = Files.list(tmp)) {
					for (Path f : (Iterable<Path>) entries::iterator) {
						Files.deleteIfExists(f);
					}
				}
				Files.deleteIfExists(tmp);
			}
		}

		/** single-blob convenience : the bytes stored under this key, or null */
		public byte[] findBlob() throws Exception {
			Path hit = find();
			return hit == null ? null : Files.readAllBytes(hit.resolve("blob"));
		}

		/** single-blob convenience : store the bytes under this key */
		public void storeBlob(byte[] bytes) throws Exception {
			store(staging -> Files.write(staging.resolve("blob"), bytes));
		}
	}
}
