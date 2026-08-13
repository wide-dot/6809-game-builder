package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * How the arena packer placed each divisible file, in full.
 *
 * A file whose top-level children can all name their parts (a tileset) is an
 * ELEMENT LIST to the placement : whole if it fits, cut between elements if
 * it does not ("entier s'il rentre, coupé sinon" — the author's rule, 5c).
 * One record carries both halves of that one decision : the MEMBERS a
 * scene's load expands to (name, page, address — null when the file was
 * placed whole and keeps its name), and what the EMISSION needs to build
 * them — which parts, grouped how, and where the generated member sources
 * go. Taken once by the packer, read by the scenes and the directory :
 * deciding twice would let the passes disagree, which the
 * reserved==emitted assertion refuses.
 */
public class Cuts {

	/** one direntry a cut collection expands to */
	public static class Member {
		public final String name;
		public final int page;
		public final int address;

		public Member(String name, int page, int address) {
			this.name = name;
			this.page = page;
			this.address = address;
		}
	}

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
		/**
		 * The {@code <unit>} nodes among the parts, by part index. A unit is
		 * one indivisible element measured and assembled ALONE (its internal
		 * names legitimately repeat between units), and its source is
		 * regenerated at emission with the member it landed in — which only
		 * the packing knows. Empty for a file of divisible content only.
		 */
		public final Map<Integer, org.apache.commons.configuration2.tree.ImmutableNode> units;
		/**
		 * The direntries a scene's load expands to, in member order — null
		 * when the file was placed whole (it keeps its name and gets a plain
		 * placement instead).
		 */
		public final List<Member> members;

		public Cut(List<String[]> parts, List<List<Integer>> chunks, String gendir,
				Map<Integer, org.apache.commons.configuration2.tree.ImmutableNode> units) {
			this(parts, chunks, gendir, units, null);
		}

		public Cut(List<String[]> parts, List<List<Integer>> chunks, String gendir,
				Map<Integer, org.apache.commons.configuration2.tree.ImmutableNode> units,
				List<Member> members) {
			this.parts = parts;
			this.chunks = chunks;
			this.gendir = gendir;
			this.units = units;
			this.members = members;
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

	/**
	 * The members a load of this name expands to — null for an ordinary or
	 * whole-placed file, which keeps its own name.
	 */
	public List<Member> members(String file) {
		Cut cut = cuts.get(file);
		return cut == null ? null : cut.members;
	}

	public void clear() {
		cuts.clear();
	}
}
