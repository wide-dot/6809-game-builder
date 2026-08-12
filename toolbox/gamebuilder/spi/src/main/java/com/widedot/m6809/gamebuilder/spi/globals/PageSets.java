package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * The members a CUT collection expands to.
 *
 * A collection the arena packer could not place whole becomes several
 * direntries — {@code <file>.0}, {@code .1}… — one per free run its elements
 * flowed into. The members are what the scenes actually load, so this is
 * where the scene generator looks up what a single {@code <load>} of the
 * file expands to. The member count is the packing's result, decided once
 * by the placement scan and read everywhere else.
 */
public class PageSets {

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

	private final Map<String, List<Member>> sets = new LinkedHashMap<String, List<Member>>();

	public void declare(String set, List<Member> members) {
		sets.put(set, members);
	}

	/** null when the name is an ordinary, uncut file */
	public List<Member> get(String set) {
		return sets.get(set);
	}

	public void clear() {
		sets.clear();
	}
}
