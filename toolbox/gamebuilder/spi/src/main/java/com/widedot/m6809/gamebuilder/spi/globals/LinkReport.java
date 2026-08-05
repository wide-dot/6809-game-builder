package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;

/**
 * What every file of a target costs in load time link data, collected as
 * the entries are built and reported once the target is done.
 *
 * The number that matters is not the disk footprint : the loader keeps a file's
 * link block in its memory pool for as long as the file stays indexed, so the
 * sum over the files indexed together is what the pool has to hold. A build
 * that overflows it stops with no message at all — see
 * {@code docs/lang/en/migration/static-link-bake.md} — and the only way to
 * arbitrate beforehand is to see the entries side by side.
 *
 * Purely observational : nothing here influences what is built.
 */
public class LinkReport {

	/** One file's contribution. */
	public static final class Entry {

		/** file name, as written in the configuration */
		public final String name;

		/** bytes of link data, and so bytes of pool while the file is indexed */
		public final int bytes;

		public final int intern;
		public final int extern8;
		public final int extern16;
		public final int externPage;
		public final int exportAbs;
		public final int exportRel;

		/** references the {@code *.static} sections resolved at build time */
		public final int baked;

		/** whether the file asked for a link block at all */
		public final boolean linkdata;

		public Entry(String name, int bytes, int intern, int extern8, int extern16,
				int externPage, int exportAbs, int exportRel, int baked, boolean linkdata) {
			this.name = name;
			this.bytes = bytes;
			this.intern = intern;
			this.extern8 = extern8;
			this.extern16 = extern16;
			this.externPage = externPage;
			this.exportAbs = exportAbs;
			this.exportRel = exportRel;
			this.baked = baked;
			this.linkdata = linkdata;
		}

		/** total references the loader has to patch for this file */
		public int references() {
			return intern + extern8 + extern16 + externPage;
		}
	}

	private final List<Entry> entries = new ArrayList<Entry>();

	public void add(Entry entry) {
		entries.add(entry);
	}

	public void clear() {
		entries.clear();
	}

	/** Every file seen, in declaration order. */
	public List<Entry> entries() {
		return Collections.unmodifiableList(entries);
	}

	/** Those that still carry link data, largest first — the arbitration order. */
	public List<Entry> costly() {
		List<Entry> out = new ArrayList<Entry>();
		for (Entry e : entries) {
			if (e.bytes > 0) out.add(e);
		}
		out.sort(Comparator.comparingInt((Entry e) -> e.bytes).reversed()
				.thenComparing(e -> e.name));
		return out;
	}

	/** What the pool holds if every file of the target is indexed at once. */
	public int totalBytes() {
		int total = 0;
		for (Entry e : entries) total += e.bytes;
		return total;
	}

	public int totalBaked() {
		int total = 0;
		for (Entry e : entries) total += e.baked;
		return total;
	}
}
