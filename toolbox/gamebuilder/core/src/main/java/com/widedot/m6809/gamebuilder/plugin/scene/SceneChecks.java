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
	 * @return the errors found, empty when all the scenes are coherent
	 */
	public static List<String> verify(List<SceneCheck> scenes, Map<String, Integer> sizes,
			Map<String, Map<String, int[]>> pageSpans) {
		List<String> errors = new ArrayList<String>();

		for (SceneCheck scene : scenes) {
			// resolved memory range of every write of this scene, per page
			List<int[]> ranges = new ArrayList<int[]>(); // {page, start, end}
			List<String> owners = new ArrayList<String>();

			// bulk regions accumulate a running cursor from their base
			Map<String, Integer> bulkCursor = new LinkedHashMap<String, Integer>();
			Map<String, SceneCheck.Load> bulkFirst = new LinkedHashMap<String, SceneCheck.Load>();

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
					}
					break;

				case BULK: {
					int base = bulkCursor.merge(load.region, size, Integer::sum) - size;
					bulkFirst.putIfAbsent(load.region, load);
					if (size > 0) {
						ranges.add(new int[] { load.page, load.address + base, load.address + base + size });
						owners.add(load.name + " (in bulk '" + load.region + "')");
					}
					break;
				}

				case EXPORT_ONLY:
					if (size > 0) {
						errors.add(load.where + ": scene " + scene.sceneName + ": '" + load.name
								+ "' carries " + size + " bytes of data but no destination ;"
								+ " give it a region, or make it export-only");
					}
					break;
				}
			}

			// bulk lists must fit their region budget
			for (Map.Entry<String, Integer> cursor : bulkCursor.entrySet()) {
				SceneCheck.Load first = bulkFirst.get(cursor.getKey());
				if (first.budget != null && cursor.getValue() > first.budget) {
					errors.add(first.where + ": scene " + scene.sceneName + ": the bulk list of region '"
							+ cursor.getKey() + "' is " + cursor.getValue() + " bytes, over its "
							+ first.budget + " byte budget");
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
		return errors;
	}

	private static String hex(int v) {
		return String.format("$%04X", v);
	}
}
