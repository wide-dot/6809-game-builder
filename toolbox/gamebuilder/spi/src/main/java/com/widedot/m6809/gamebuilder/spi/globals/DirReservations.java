package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.HashMap;
import java.util.Map;
import java.util.Set;

/**
 * File-id reservations of every {@code <directory>} of the target, computed
 * by the placement scan BEFORE anything assembles.
 *
 * <p>Why before : the id equates of one directory are consumed by units that
 * live in ANOTHER directory (a stage's main names the next stage's scene,
 * the title names the first stage's, that stage names the title's — a
 * cycle), so no declaration order can serve them if each directory writes
 * its equates only when its own turn comes. The scan reserves every
 * directory in declaration order — ids stay global and continuous, exactly
 * as before — writes every gensymbols file, and the directory emission
 * reads its reservation back from here instead of recomputing it.</p>
 */
public class DirReservations {

	/** What one directory reserved : its id range and its name→id map. */
	public static final class Reservation {
		/** Global file id of the directory's first entry. */
		public final int baseId;
		/** First id AFTER the directory (baseId of the next one). */
		public final int endId;
		/** Entry name → { first id, block count }. */
		public final Map<String, int[]> idBlocks;
		/** Every name the directory declares (reference checks). */
		public final Set<String> names;

		public Reservation(int baseId, int endId, Map<String, int[]> idBlocks,
				Set<String> names) {
			this.baseId = baseId;
			this.endId = endId;
			this.idBlocks = idBlocks;
			this.names = names;
		}
	}

	private final Map<Integer, Reservation> byId = new HashMap<Integer, Reservation>();

	public void declare(int directoryId, Reservation r) {
		byId.put(directoryId, r);
	}

	/** every reservation, directory id → what it reserved */
	public Map<Integer, Reservation> all() {
		return java.util.Collections.unmodifiableMap(byId);
	}

	public Reservation get(int directoryId) {
		return byId.get(directoryId);
	}

	public void clear() {
		byId.clear();
	}
}
