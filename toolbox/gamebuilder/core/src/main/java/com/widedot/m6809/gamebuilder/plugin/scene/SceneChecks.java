package com.widedot.m6809.gamebuilder.plugin.scene;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Scene verification pass, run once every entry of the directory is built and
 * the uncompressed sizes are known.
 *
 * Everything here is local to one scene : one composition must be coherent in
 * itself. Sequencing compositions belongs to the game code — the builder does
 * not know the runtime order, so it checks nothing across scenes (see
 * docs/lang/fr/modele-regions-2026-07.md).
 */
public final class SceneChecks {

	private SceneChecks() {
	}

	/**
	 * @param scenes what each scene declared
	 * @param sizes  uncompressed size of every directory entry, by name
	 * @return the errors found, empty when all the scenes are coherent
	 */
	public static List<String> verify(List<SceneCheck> scenes, Map<String, Integer> sizes) {
		return verify(scenes, sizes, java.util.Collections.<String, Map<String, int[]>>emptyMap());
	}

	/**
	 * @param scenes    what each scene declared
	 * @param sizes     uncompressed size of every directory entry, by name
	 * @param pageSpans per entry, the ranges that must stay inside one 256 byte
	 *                  page, as offsets in the file
	 * @param reserved  the layout's {@code <reserved>} ranges : bytes the game
	 *                  occupies without loading into them, that no load may touch
	 * @return the errors found, empty when all the scenes are coherent
	 */
	public static List<String> verify(List<SceneCheck> scenes, Map<String, Integer> sizes,
			Map<String, Map<String, int[]>> pageSpans, boolean addressesAreReal,
			List<com.widedot.m6809.gamebuilder.spi.globals.Regions.Reserved> reserved) {
		List<String> errors = verify(scenes, sizes, pageSpans, reserved);
		return addressesAreReal ? errors : budgetsOnly(errors);
	}

	/**
	 * While the layout is being measured, an arena's files all sit at
	 * provisional addresses : they would look piled on each other. Budgets and
	 * missing files still mean something, overlaps do not — the pass whose job
	 * is to produce the real addresses must not be stopped by the absence of
	 * real addresses. A reserved range clash reads the same addresses, so it
	 * waits for the real pass too.
	 */
	private static List<String> budgetsOnly(List<String> errors) {
		List<String> kept = new ArrayList<String>();
		for (String e : errors) {
			if (!e.contains("overlap on page") && !e.contains("runs into the reserved range")) {
				kept.add(e);
			}
		}
		return kept;
	}

	public static List<String> verify(List<SceneCheck> scenes, Map<String, Integer> sizes,
			Map<String, Map<String, int[]>> pageSpans) {
		return verify(scenes, sizes, pageSpans,
				java.util.Collections.<com.widedot.m6809.gamebuilder.spi.globals.Regions.Reserved>emptyList());
	}

	public static List<String> verify(List<SceneCheck> scenes, Map<String, Integer> sizes,
			Map<String, Map<String, int[]>> pageSpans,
			List<com.widedot.m6809.gamebuilder.spi.globals.Regions.Reserved> reserved) {
		List<String> errors = new ArrayList<String>();
		// the same file loaded at the same place by several scenes clashes
		// identically in each : one report per (file, range) is what a human
		// needs, so the messages dedup on their text
		java.util.Set<String> reservedClashes = new java.util.LinkedHashSet<String>();

		for (SceneCheck scene : scenes) {
			// resolved memory range of every write of this scene, per page
			List<int[]> ranges = new ArrayList<int[]>(); // {page, start, end}
			List<String> owners = new ArrayList<String>();

			for (SceneCheck.Load load : scene.loads) {
				Integer size = sizes.get(load.name);
				if (size == null) {
					// reference errors are reported at generation time
					continue;
				}

				switch (load.kind) {
				case PLACED:
					// Code that reads its own bytes through the direct page carries
					// only their low byte, so those bytes must share the page the
					// DP register holds. Where the file lands is decided here, and
					// only here — the assembler never sees this address.
					for (Map.Entry<String, int[]> span :
							pageSpans.getOrDefault(load.name,
									java.util.Collections.<String, int[]>emptyMap()).entrySet()) {
						int from = load.address + span.getValue()[0];
						int to = load.address + span.getValue()[1];
						if ((from >> 8) != (to >> 8)) {
							errors.add(load.where + ": scene " + scene.sceneName + ": '" + load.name
									+ "' at $" + Integer.toHexString(load.address).toUpperCase()
									+ " puts the '" + span.getKey() + "' range across a page"
									+ " boundary ($" + Integer.toHexString(from).toUpperCase()
									+ "..$" + Integer.toHexString(to).toUpperCase() + ")."
									+ " That code reads those bytes through the direct page, which"
									+ " cannot span two pages : move the region or the routine.");
						}
					}
					if (load.budget != null && size > load.budget) {
						errors.add(load.where + ": scene " + scene.sceneName + ": '" + load.name
								+ "' is " + size + " bytes, over the " + load.budget
								+ " byte budget of region '" + load.region + "'");
					}
					if (size > 0) {
						ranges.add(new int[] { load.page, load.address, load.address + size });
						owners.add(load.name);
						// a reserved range is a promise about where loads must
						// NOT land : the object pool, the globals, the stack —
						// bytes the game occupies without loading into them.
						// The r-type title grew one byte past its span and its
						// last palette byte landed ON the bench witnesses, which
						// stamped it every frame ; nothing said a word. Refused
						// here, with the file's real size, whatever the
						// destination form (raw, region or arena).
						for (com.widedot.m6809.gamebuilder.spi.globals.Regions.Reserved r : reserved) {
							if (load.page == r.page && load.address < r.address + r.size
									&& r.address < load.address + size) {
								reservedClashes.add(load.where + ": '" + load.name + "' ["
										+ hex(load.address) + "-" + hex(load.address + size - 1)
										+ "] runs into the reserved range '" + r.name + "' ["
										+ hex(r.address) + "-" + hex(r.address + r.size - 1)
										+ "] on page " + load.page + " — those bytes belong to the"
										+ " game's own equates ; shrink the file or move the range");
							}
						}
					}
					break;

				case EXPORT_ONLY:
					// this is what lets the loader's sequential blocks skip the
					// whole placement arithmetic : a load without a place is
					// export-only, and an export-only file never writes a byte
					if (size > 0) {
						errors.add(load.where + ": scene " + scene.sceneName + ": '" + load.name
								+ "' carries " + size + " bytes of data but no destination ;"
								+ " a load without a place is export-only and loads nothing —"
								+ " give the file a place, or strip its data");
					}
					break;
				}
			}

			// one composition must be coherent in itself : no two writes of
			// the same scene may land on each other
			for (int i = 0; i < ranges.size(); i++) {
				for (int j = i + 1; j < ranges.size(); j++) {
					int[] a = ranges.get(i);
					int[] b = ranges.get(j);
					if (a[0] == b[0] && a[1] < b[2] && b[1] < a[2]) {
						errors.add("scene " + scene.sceneName + ": '" + owners.get(i) + "' ["
								+ hex(a[1]) + "-" + hex(a[2]) + "] and '" + owners.get(j) + "' ["
								+ hex(b[1]) + "-" + hex(b[2]) + "] overlap on page " + a[0]);
					}
				}
			}
		}
		errors.addAll(reservedClashes);
		return errors;
	}

	private static String hex(int v) {
		return String.format("$%04X", v);
	}
}
