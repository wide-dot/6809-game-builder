package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * What each scene actually puts in memory, kept for the occupancy map written
 * at the end of a target.
 *
 * Destinations are placed by hand, against budgets worked out once. Nothing
 * said what was left over : a region's declared size is a promise, not a
 * measurement, and the difference between the two is exactly the room a new
 * object can take. This is where the measurement is collected.
 *
 * One entry per load, per scene — a composition is what gets optimised, so it
 * is the unit reported. Sequences of scenes are not modelled here : the
 * builder does not know them (see docs/lang/fr/modele-regions-2026-07.md).
 */
public class RamMap {

	/** one file landing somewhere, as the scene declared it */
	public static class Load {
		public final String name;
		/** region it lands in, null for a raw page/address destination */
		public final String region;
		public final int page;
		public final int address;
		/** uncompressed size, what the region actually holds */
		public final int size;

		public Load(String name, String region, int page, int address, int size) {
			this.name = name;
			this.region = region;
			this.page = page;
			this.address = address;
			this.size = size;
		}
	}

	private final Map<String, List<Load>> scenes = new LinkedHashMap<String, List<Load>>();

	/**
	 * Forget a scene before re-recording it. The build runs several passes
	 * and the map survives them : without this, every pass appended the same
	 * loads again — each file collided with itself in the report, and the
	 * pool map summed every scene twice.
	 */
	public void forget(String scene) {
		scenes.remove(scene);
	}

	public void record(String scene, Load load) {
		scenes.computeIfAbsent(scene, s -> new ArrayList<Load>()).add(load);
	}

	/** scene name -> what it loads, in declaration order */
	public Map<String, List<Load>> scenes() {
		return Collections.unmodifiableMap(scenes);
	}

	/**
	 * What each region really holds : the largest a scene ever puts in it.
	 *
	 * The largest, not the last : a region hosting alternatives — the stage
	 * boundary — must be sized for the biggest of them, or loading the other
	 * one overflows. Loads of a same scene are summed — that is what a
	 * multi-zone region or an arena holds ; an ordinary region only ever
	 * takes one per scene.
	 *
	 * This is what {@code size="auto"} resolves to, measured by the discovery
	 * pass and applied by the real one.
	 */
	public Map<String, Integer> contentSizes() {
		Map<String, Integer> max = new LinkedHashMap<String, Integer>();
		for (List<Load> loads : scenes.values()) {
			Map<String, Integer> perScene = new LinkedHashMap<String, Integer>();
			for (Load load : loads) {
				if (load.region == null) {
					continue;    // a raw page/address destination has no region to size
				}
				Integer sum = perScene.get(load.region);
				perScene.put(load.region, (sum == null ? 0 : sum) + load.size);
			}
			for (Map.Entry<String, Integer> e : perScene.entrySet()) {
				Integer known = max.get(e.getKey());
				if (known == null || e.getValue() > known) {
					max.put(e.getKey(), e.getValue());
				}
			}
		}
		return max;
	}

	/**
	 * What each FILE measured — the counterpart of contentSizes for an arena,
	 * which places files and not regions. The largest seen, for the same reason
	 * : a name loaded by two scenes must be sized for the bigger.
	 */
	public Map<String, Integer> fileSizes() {
		Map<String, Integer> max = new LinkedHashMap<String, Integer>();
		for (List<Load> loads : scenes.values()) {
			for (Load load : loads) {
				Integer known = max.get(load.name);
				if (known == null || load.size > known) {
					max.put(load.name, load.size);
				}
			}
		}
		return max;
	}

	public boolean isEmpty() {
		return scenes.isEmpty();
	}

	public void clear() {
		scenes.clear();
	}
}
