package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * The attributed place of a file : the destination declared on its own
 * {@code <file>} element instead of on every {@code <load>} that names it.
 *
 * In the target model the file is the unit of everything — name, loading,
 * lifetime, destination — and a scene load reduces to a name. Declaring the
 * place once, on the file, makes the uniqueness of its destination
 * structural : there is nothing left for two scenes to disagree about,
 * where the per-load form could only verify their agreement after the fact.
 *
 * A file declares at most one of : {@code arena} (the builder picks the page
 * and address), {@code region} (a named place of the layout), or a literal
 * {@code page} + {@code address}. A load that names such a file must not
 * carry a destination of its own — one truth, kept structural. Files that
 * declare nothing keep the historical per-load behaviour, which is what
 * makes the attributed place additive during the migration.
 */
public class FilePlaces {

	/** one attributed destination — exactly one of the three forms is set */
	public static class Place {
		public final String arena;
		public final String region;
		public final Integer page;
		public final Integer address;
		/** source position of the declaring element, for error messages */
		public final String where;

		public Place(String arena, String region, Integer page, Integer address,
				String where) {
			this.arena = arena;
			this.region = region;
			this.page = page;
			this.address = address;
			this.where = where;
		}

		public String describe() {
			if (arena != null) return "arena '" + arena + "'";
			if (region != null) return "region '" + region + "'";
			return String.format("page %d $%04X", page, address);
		}

		private boolean same(Place other) {
			return java.util.Objects.equals(arena, other.arena)
					&& java.util.Objects.equals(region, other.region)
					&& java.util.Objects.equals(page, other.page)
					&& java.util.Objects.equals(address, other.address);
		}
	}

	private final Map<String, Place> places = new LinkedHashMap<String, Place>();

	/**
	 * Record a file's attributed place. Redeclaring the same place is
	 * tolerated ; redeclaring a different one is refused — the whole point
	 * of the attribute is that a file has one destination.
	 */
	public void declare(String file, Place place) throws Exception {
		Place known = places.get(file);
		if (known == null) {
			places.put(file, place);
			return;
		}
		if (!known.same(place)) {
			throw new Exception(place.where + ": file '" + file + "' already declared "
					+ known.describe() + " (" + known.where + ") — a file has one"
					+ " attributed place");
		}
	}

	/** the attributed place of a file, or null when it declares none */
	public Place get(String file) {
		return places.get(file);
	}

	public void clear() {
		places.clear();
	}
}
