package com.widedot.m6809.gamebuilder.plugin.layout;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.globals.Compositions;
import com.widedot.m6809.gamebuilder.spi.globals.RamMap;

import lombok.extern.slf4j.Slf4j;

/**
 * Verifies the declared RAM states, at the end of a target.
 *
 * {@link com.widedot.m6809.gamebuilder.plugin.scene.SceneChecks} verifies one
 * scene, completely — and says itself that it checks nothing across scenes.
 * That was the whole of it as long as a scene was taken for the whole of
 * memory. A game that loads several scenes on top of one another needs the
 * composition to say what is resident together ; this is where the same
 * overlap test runs over the union.
 *
 * Three things are checked, and no more :
 * <ul>
 * <li>a composition names scenes that exist ;</li>
 * <li>every scene belongs to at least one composition — the missing
 * declaration is the failure this whole mechanism exists to catch, so it is an
 * error, not a warning ;</li>
 * <li>inside a composition, no two files land on each other ;</li>
 * <li>a file is loaded by one scene only — the invariant a scene-granular
 * convergence rests on (see {@code sharedFiles}).</li>
 * </ul>
 *
 * What is NOT checked : that a composition tells the truth. Omitting a scene
 * that the game really loads on top gives a reference that is too small, and
 * no static analysis can tell — the game code does the sequencing. Generating
 * what the game consumes from these declarations is what closes that door.
 *
 * A configuration that declares no composition is not refused — everything
 * written before this mechanism stays valid — but it is not passed over in
 * silence either : if two of its scenes share bytes, the build says how many
 * pairs it could not check. An unverified build must not read like a clean one.
 */
@Slf4j
public final class CompositionChecks {

	private CompositionChecks() {
	}

	public static void verify(BuildContext ctx) throws Exception {
		if (ctx.compositions.isEmpty()) {
			// Nothing declared : the co-residency of scenes cannot be checked.
			// That silence is only harmless when no two scenes share bytes in
			// the first place, so say WHAT is left unverified rather than say
			// nothing — an unchecked build must not look like a clean one.
			List<String> sharing = crossSceneSharing(ctx.ramMap.scenes());
			if (!sharing.isEmpty()) {
				log.warn("no <composition> declared : {} pair(s) of files from different scenes"
						+ " share bytes, and nothing says whether those scenes are in memory"
						+ " together. Declare the RAM states to have them checked.",
						sharing.size());
				for (String pair : sharing.subList(0, Math.min(5, sharing.size()))) {
					log.warn("  {}", pair);
				}
				if (sharing.size() > 5) {
					log.warn("  ... and {} more", sharing.size() - 5);
				}
			}
			return;
		}

		Map<String, List<RamMap.Load>> scenes = ctx.ramMap.scenes();
		List<String> errors = new ArrayList<String>();
		Set<String> named = new LinkedHashSet<String>();

		for (Compositions.Composition c : ctx.compositions.all()) {
			for (String scene : c.scenes) {
				named.add(scene);
				if (!scenes.containsKey(scene)) {
					errors.add("composition '" + c.name + "' (" + c.where + ") names the scene '"
							+ scene + "', which no <scene> declares");
				}
			}
		}

		for (String scene : scenes.keySet()) {
			if (!named.contains(scene)) {
				errors.add("the scene '" + scene + "' belongs to no composition — say what is in"
						+ " memory beside it, even if the answer is that scene alone");
			}
		}

		errors.addAll(sharedFiles(scenes));

		for (Compositions.Composition c : ctx.compositions.all()) {
			errors.addAll(overlaps(c, scenes));
		}

		if (!errors.isEmpty()) {
			throw new Exception("the declared RAM states do not hold:" + System.lineSeparator()
					+ "  " + String.join(System.lineSeparator() + "  ", errors)
					+ System.lineSeparator()
					+ "  a composition is what may be in RAM at one time : two files it holds"
					+ " cannot share bytes. Move one of them to a place the other composition"
					+ " does not use, or stop loading it there.");
		}
	}

	/**
	 * A file may be loaded by ONE scene.
	 *
	 * This is the invariant the runtime convergence rests on : a composition
	 * is a set of scenes, so what it drops and what it takes is decided scene
	 * by scene. Let two scenes carry the same file and dropping one of them
	 * takes a file the other still needs — the loader would have to reason
	 * per file, which means an index of every resident file, which is exactly
	 * the knowledge it does not have (it indexes only what carries link data).
	 *
	 * Measured when the rule was written : the corpus honours it everywhere
	 * but in loader-ut, which loads one file from two scenes on purpose to arm
	 * its LOAD_OVERLAP trap. Hence the scope — only a configuration that
	 * declares compositions is held to it.
	 */
	private static List<String> sharedFiles(Map<String, List<RamMap.Load>> scenes) {
		Map<String, List<String>> owners = new LinkedHashMap<String, List<String>>();
		for (Map.Entry<String, List<RamMap.Load>> scene : scenes.entrySet()) {
			for (RamMap.Load load : scene.getValue()) {
				List<String> by = owners.computeIfAbsent(load.name,
						n -> new ArrayList<String>());
				if (!by.contains(scene.getKey())) {
					by.add(scene.getKey());
				}
			}
		}
		List<String> found = new ArrayList<String>();
		for (Map.Entry<String, List<String>> file : owners.entrySet()) {
			if (file.getValue().size() > 1) {
				found.add("'" + file.getKey() + "' is loaded by " + file.getValue().size()
						+ " scenes (" + String.join(", ", file.getValue()) + ") — a file"
						+ " belongs to one scene, or dropping a scene takes bytes another"
						+ " one still needs");
			}
		}
		return found;
	}

	/**
	 * Files of DIFFERENT scenes landing on the same bytes. The packer made
	 * them alternatives because no single scene loads both — which is sound
	 * only as long as a scene is the whole of memory. Every pair here is a
	 * question the builder cannot answer without a composition.
	 */
	private static List<String> crossSceneSharing(Map<String, List<RamMap.Load>> scenes) {
		Map<String, RamMap.Load> byFile = new LinkedHashMap<String, RamMap.Load>();
		Map<String, String> owner = new LinkedHashMap<String, String>();
		for (Map.Entry<String, List<RamMap.Load>> scene : scenes.entrySet()) {
			for (RamMap.Load load : scene.getValue()) {
				if (load.size > 0 && byFile.putIfAbsent(load.name, load) == null) {
					owner.put(load.name, scene.getKey());
				}
			}
		}
		List<RamMap.Load> all = new ArrayList<RamMap.Load>(byFile.values());
		List<String> found = new ArrayList<String>();
		for (int i = 0; i < all.size(); i++) {
			for (int j = i + 1; j < all.size(); j++) {
				RamMap.Load a = all.get(i);
				RamMap.Load b = all.get(j);
				if (a.page != b.page || a.address >= b.address + b.size
						|| b.address >= a.address + a.size
						|| owner.get(a.name).equals(owner.get(b.name))) {
					continue;
				}
				found.add(String.format("'%s' (%s) and '%s' (%s) share page %d",
						a.name, owner.get(a.name), b.name, owner.get(b.name), a.page));
			}
		}
		return found;
	}

	/**
	 * The same pairwise test SceneChecks runs inside one scene, over the union
	 * of the composition's scenes.
	 *
	 * One file loaded by two of them is not a collision : reloading a file
	 * onto its own bytes is what dedup is for. It is kept once, under the
	 * first scene that names it.
	 */
	private static List<String> overlaps(Compositions.Composition c,
			Map<String, List<RamMap.Load>> scenes) {

		Map<String, RamMap.Load> byFile = new LinkedHashMap<String, RamMap.Load>();
		Map<String, String> owner = new LinkedHashMap<String, String>();
		for (String scene : c.scenes) {
			List<RamMap.Load> loads = scenes.get(scene);
			if (loads == null) {
				continue;
			}
			for (RamMap.Load load : loads) {
				if (load.size <= 0) {
					continue;
				}
				if (byFile.putIfAbsent(load.name, load) == null) {
					owner.put(load.name, scene);
				}
			}
		}

		List<RamMap.Load> all = new ArrayList<RamMap.Load>(byFile.values());
		List<String> found = new ArrayList<String>();
		for (int i = 0; i < all.size(); i++) {
			for (int j = i + 1; j < all.size(); j++) {
				RamMap.Load a = all.get(i);
				RamMap.Load b = all.get(j);
				if (a.page != b.page || a.address >= b.address + b.size
						|| b.address >= a.address + a.size) {
					continue;
				}
				found.add(String.format(
						"composition '%s': '%s' [$%04X-$%04X] (%s) and '%s' [$%04X-$%04X] (%s)"
						+ " overlap on page %d",
						c.name,
						a.name, a.address, a.address + a.size - 1, owner.get(a.name),
						b.name, b.address, b.address + b.size - 1, owner.get(b.name),
						a.page));
			}
		}
		return found;
	}
}
