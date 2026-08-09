package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Datasets spread over the pages of a multi-page region.
 *
 * A pageset is one authored declaration that becomes several direntries — one
 * per page of its region — because no single file may exceed a page. The
 * members are what the scenes actually load, so this is where the scene
 * generator looks up what a single {@code <load>} of a pageset expands to.
 *
 * The member count is the packing's result : the directory measures and packs
 * the set at the moment it reserves file ids, so only filled pages become
 * members. A budget the packing does not fill simply yields fewer members —
 * the build says how many zones could be given back.
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

	/** the member names a pageset of this many pages will produce, in page order */
	public static List<String> memberNames(String set, int pages) {
		List<String> names = new ArrayList<String>();
		for (int i = 0; i < pages; i++) {
			names.add(set + "." + i);
		}
		return names;
	}

	public void declare(String set, List<Member> members) {
		sets.put(set, members);
	}

	/** null when the name is an ordinary file rather than a pageset */
	public List<Member> get(String set) {
		return sets.get(set);
	}

	public void clear() {
		sets.clear();
	}
}
