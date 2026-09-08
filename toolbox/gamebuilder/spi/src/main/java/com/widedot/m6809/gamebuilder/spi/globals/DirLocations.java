package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

/**
 * Where every {@code <directory>} of the target sits on its media, id by
 * id — the registry behind the loader's location table
 * ({@code gen/directories/locations.asm}).
 *
 * A directory at a declared section knows its spot from the configuration
 * alone : the placement scan records it before anything assembles. A
 * COLOCATED directory — written in its section right before the content it
 * lists — only learns it when it is emitted : its row starts unresolved and
 * the emission resolves it, rewriting the table. Whoever assembles the
 * table before then gets an assembly error naming the directory, not a
 * silent zero (the loader would read a boot sector as a directory).
 */
public class DirLocations {

	public static final class Row {
		public final int disk;
		public final String section;
		public final boolean colocated;
		/** null until resolved : face, track, sector (0-based) */
		public int[] where;

		public Row(int disk, String section, boolean colocated, int[] where) {
			this.disk = disk;
			this.section = section;
			this.colocated = colocated;
			this.where = where;
		}

		public boolean resolved() {
			return where != null;
		}
	}

	private final Map<Integer, Row> byId = new HashMap<Integer, Row>();

	/**
	 * The part of the generated table that does not depend on the rows — the
	 * media's interleave, in assembler text — kept so that a resolution can
	 * rewrite the whole file. Shared by every child context, unlike anything
	 * keyed on a context instance.
	 */
	public String trailer;

	/** how many directories the emission has completed : the index size is only final after the last */
	public int emitted;

	public void declare(int id, Row row) {
		byId.put(id, row);
	}

	public Row get(int id) {
		return byId.get(id);
	}

	public Map<Integer, Row> all() {
		return Collections.unmodifiableMap(byId);
	}

	/** the emission of a colocated directory reporting where it landed */
	public void resolve(int id, int face, int track, int sector) throws Exception {
		Row row = byId.get(id);
		if (row == null) {
			throw new Exception("directory " + id + " has no location row — the placement"
					+ " scan did not see it");
		}
		row.where = new int[] { face, track, sector };
	}

	public boolean isEmpty() {
		return byId.isEmpty();
	}

	public void clear() {
		byId.clear();
		trailer = null;
		emitted = 0;
	}
}
