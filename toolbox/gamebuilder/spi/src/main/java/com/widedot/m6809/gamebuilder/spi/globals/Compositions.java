package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * The declared compositions : which scenes are resident TOGETHER.
 *
 * A scene is a list of loads, nothing more. What a scene never said is what
 * else is in memory beside it — and a game that loads several scenes on top of
 * one another (a stage plus the lots its cast needs) composes its RAM from
 * more than one of them. The packer places a file at an address free "in every
 * composition it appears in", and until now it read composition = scene : two
 * files no single scene loaded together were taken for alternatives and given
 * the same bytes. When the game keeps both, the second load lands on the first
 * — silently, since a file carrying no link data never registers and so evicts
 * nothing, leaving the loader's global re-link to patch a stale slot into the
 * new content.
 *
 * A composition is that missing reference, and nothing else : a name and the
 * scenes it holds. Sequencing — who unloads what, in which order — stays out of
 * it ; that is the loader's business at run time (LOAD_OVERLAP). The builder
 * owns the space, the loader owns the time.
 *
 * Over-declaring is the safe direction : naming a scene that is only sometimes
 * there constrains the placement more, never less.
 */
public class Compositions {

	/** one declared RAM state */
	public static class Composition {
		public final String name;
		/** the scenes resident together, in declaration order */
		public final List<String> scenes;
		/** where it was declared, for error messages */
		public final String where;

		public Composition(String name, List<String> scenes, String where) {
			this.name = name;
			this.scenes = Collections.unmodifiableList(new ArrayList<String>(scenes));
			this.where = where;
		}
	}

	private final Map<String, Composition> byName = new LinkedHashMap<String, Composition>();

	/**
	 * @throws Exception if the name is already taken — two compositions of one
	 *                   name would silently merge, and the reader could not
	 *                   tell which one the check used
	 */
	public void declare(Composition composition) throws Exception {
		Composition previous = byName.get(composition.name);
		if (previous != null) {
			throw new Exception("composition '" + composition.name + "' is declared twice ("
					+ previous.where + " and " + composition.where + ")");
		}
		byName.put(composition.name, composition);
	}

	/** every composition, in declaration order */
	public Collection<Composition> all() {
		return Collections.unmodifiableCollection(byName.values());
	}

	public boolean isEmpty() {
		return byName.isEmpty();
	}

	public void clear() {
		byName.clear();
	}
}
