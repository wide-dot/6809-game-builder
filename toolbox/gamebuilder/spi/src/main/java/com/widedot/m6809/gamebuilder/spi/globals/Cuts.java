package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * How each divisible file was cut by the arena packer — the other half of
 * what {@link PageSets} records.
 *
 * A file whose top-level children can all name their parts (a tileset) is an
 * ELEMENT LIST to the placement : whole if it fits, cut between elements if
 * it does not ("entier s'il rentre, coupé sinon" — the author's rule, 5c).
 * PageSets carries the members a scene expands to ; this registry carries
 * what the EMISSION needs to build them — which parts, grouped how, and
 * where the generated member sources go. One decision, taken once by the
 * packer, read by the directory : deciding twice would let the passes
 * disagree, which the reserved==emitted assertion refuses.
 */
public class Cuts {

	public static class Cut {
		/** every part of the file, {generated source path, exported symbol} */
		public final List<String[]> parts;
		/**
		 * Part indexes per member, in member order. A single chunk means the
		 * file was placed WHOLE : one entry, keeping the file's own name.
		 */
		public final List<List<Integer>> chunks;
		/** where the generated member sources are written */
		public final String gendir;

		public Cut(List<String[]> parts, List<List<Integer>> chunks, String gendir) {
			this.parts = parts;
			this.chunks = chunks;
			this.gendir = gendir;
		}
	}

	private final Map<String, Cut> cuts = new LinkedHashMap<String, Cut>();

	public void declare(String file, Cut cut) {
		cuts.put(file, cut);
	}

	/** null when the name is not a divisible file the packer cut or placed */
	public Cut get(String file) {
		return cuts.get(file);
	}

	public void clear() {
		cuts.clear();
	}
}
