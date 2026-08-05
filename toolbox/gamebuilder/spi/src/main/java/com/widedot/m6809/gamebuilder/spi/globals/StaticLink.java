package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Build-time resolution of the references a section opts into by naming
 * convention : a section whose name ends with ".static" asks the builder to
 * resolve its external references against the declared placement of their
 * providers, instead of emitting load-time link data for them.
 *
 * The load-time linker exists for named API symbols — few of them, referenced
 * by code, possibly swapped at run time. Generated tables (a tilemap, an
 * imageset index) are the other kind : hundreds of references whose values
 * the builder already knows, because it placed the providers itself. Sending
 * those through the loader costs kilobytes of link data and a linear symbol
 * search per reference, for addresses that never change.
 *
 * Two facts have to meet for a static resolution :
 *
 *  - where a provider lands. Collected from every scene of the target before
 *    it runs, so declaration order does not matter for placements. A file
 *    loaded at two different destinations is recorded as conflicting, and any
 *    static reference to it becomes a build error — never a silent fallback :
 *    the section name is a promise, breaking it has to be heard.
 *
 *  - at which offset inside its file a symbol sits. Known only once the
 *    provider is assembled, so it is registered as each file is built —
 *    which is why a provider consumed statically must be declared before its
 *    consumer in the configuration.
 *
 * What this cannot see : a game loading a file at a run-time computed address
 * through the loader's API. The section marker is the author's assertion that
 * the referenced content is scene-placed only ; the builder verifies it
 * against everything declared.
 */
public class StaticLink {

	/** where a file is loaded, according to the scenes of the target */
	public static class Placement {
		public final int page;
		public final int address;
		/** the scene that placed it, for error messages */
		public final String scene;

		public Placement(int page, int address, String scene) {
			this.page = page;
			this.address = address;
			this.scene = scene;
		}
	}

	/** a symbol some file exports, at an offset inside its binary */
	public static class Export {
		public final String file;
		public final int value;
		/** a constant-section export : the value stands alone, no placement */
		public final boolean absolute;

		public Export(String file, int value, boolean absolute) {
			this.file = file;
			this.value = value;
			this.absolute = absolute;
		}
	}

	private final Map<String, Placement> placements = new LinkedHashMap<String, Placement>();
	/** file -> why it cannot be resolved statically */
	private final Map<String, String> conflicts = new LinkedHashMap<String, String>();
	/**
	 * symbol -> provider file -> export. Keyed twice because run-time
	 * alternatives legitimately export the same names (each stage exports its
	 * wave), each with its own value : a single-slot map silently kept
	 * whichever registered last, and a consumer baked against it by luck of
	 * declaration order. resolve() now picks the provider the consumer can
	 * actually see at run time, or refuses when several remain.
	 */
	private final Map<String, LinkedHashMap<String, Export>> exports = new LinkedHashMap<String, LinkedHashMap<String, Export>>();
	/**
	 * scene -> direntries it loads, as PlacementScan declared them. This is
	 * what disambiguates a multi-provider symbol : a provider only reachable
	 * through scenes that also load an alternative of the consumer can never
	 * be in memory with it.
	 */
	private final Map<String, java.util.LinkedHashSet<String>> sceneLoads = new LinkedHashMap<String, java.util.LinkedHashSet<String>>();
	/** the file being built, for resolutions that lack an explicit consumer */
	private String currentConsumer = null;
	/**
	 * consumer -> external symbols its baked sections referenced, recorded
	 * during discovery. The pass end classifies them against the finished
	 * harvest to predict which ones AUTO will leave load-time linked — those
	 * must count as imports, or the pruning would drop their providers'
	 * exports and the loader would resolve them to zero.
	 */
	private final Map<String, java.util.LinkedHashSet<String>> candidates = new LinkedHashMap<String, java.util.LinkedHashSet<String>>();
	/**
	 * Discovery mode : the target's first pass exists to collect symbols and
	 * placements, and its binaries are thrown away. While it is on, baking
	 * marks references as statically consumed without resolving them — so a
	 * consumer declared before its provider no longer kills the pass, and the
	 * harvest below is always complete.
	 */
	private boolean discovery = false;
	/** interface region name -> its destination ; declared with interface="true" */
	private final Map<String, int[]> interfaceRegions = new LinkedHashMap<String, int[]>();
	/**
	 * file -> every destination any scene gives it, kept even when they
	 * conflict : the interface check must see a member that also loads
	 * elsewhere, which the single-placement map forgets.
	 */
	private final Map<String, java.util.LinkedHashSet<String>> allDestinations = new LinkedHashMap<String, java.util.LinkedHashSet<String>>();

	/** record where a scene loads a file ; a second, different destination turns into a conflict */
	public void place(String file, int page, int address, String scene) {
		// pageset members are placed under a pseudo scene ("pageset <name>") ;
		// only real scenes describe what is in memory together
		if (scene != null && !scene.startsWith("pageset ")) {
			java.util.LinkedHashSet<String> loads = sceneLoads.get(scene);
			if (loads == null) {
				loads = new java.util.LinkedHashSet<String>();
				sceneLoads.put(scene, loads);
			}
			loads.add(file);
		}
		java.util.LinkedHashSet<String> dests = allDestinations.get(file);
		if (dests == null) {
			dests = new java.util.LinkedHashSet<String>();
			allDestinations.put(file, dests);
		}
		dests.add(destKey(page, address));
		if (conflicts.containsKey(file)) {
			return;
		}
		Placement known = placements.get(file);
		if (known == null) {
			placements.put(file, new Placement(page, address, scene));
			return;
		}
		if (known.page != page || known.address != address) {
			conflicts.put(file, String.format(
					"loaded at page %d $%04X by scene %s, but at page %d $%04X by scene %s",
					known.page, known.address, known.scene, page, address, scene));
			placements.remove(file);
		}
	}

	/** record a destination that cannot serve static references, with the reason */
	public void placeConflict(String file, String reason) {
		if (!conflicts.containsKey(file)) {
			conflicts.put(file, reason);
			placements.remove(file);
		}
	}

	public void registerExport(String symbol, String file, int value, boolean absolute) {
		// duplicate exports across a target are rejected by the link symbol
		// table already — except between run-time alternatives, which SHOULD
		// share names, each with its own value
		LinkedHashMap<String, Export> byProvider = exports.get(symbol);
		if (byProvider == null) {
			byProvider = new LinkedHashMap<String, Export>();
			exports.put(symbol, byProvider);
		}
		byProvider.put(file, new Export(file, value, absolute));
	}

	/** the file whose references are being resolved, set by the builder
	 *  around each unit so generators can resolve without threading a name */
	public void setCurrentConsumer(String file) {
		currentConsumer = file;
	}

	public void setDiscovery(boolean discovery) {
		this.discovery = discovery;
	}

	/** an external reference seen in a baked section during discovery */
	public void recordCandidate(String consumer, String symbol) {
		java.util.LinkedHashSet<String> set = candidates.get(consumer);
		if (set == null) {
			set = new java.util.LinkedHashSet<String>();
			candidates.put(consumer, set);
		}
		set.add(symbol);
	}

	/**
	 * Which recorded candidates the real pass will leave load-time linked,
	 * classified against the finished harvest — the exact resolution the real
	 * bake will attempt, attempted here. {@code $PAGE} references are skipped :
	 * when linked they emit a FILE id, not a symbol id, so they neither need a
	 * preseeded name nor keep any export alive.
	 */
	public java.util.Set<String> predictLinkedImports() {
		java.util.TreeSet<String> linked = new java.util.TreeSet<String>();
		for (Map.Entry<String, java.util.LinkedHashSet<String>> consumer : candidates.entrySet()) {
			for (String symbol : consumer.getValue()) {
				if (symbol.endsWith("$PAGE")) {
					continue;
				}
				try {
					Export export = electProvider(symbol, consumer.getKey());
					if (!export.absolute) {
						placementOf(export.file, symbol);
					}
				} catch (Exception e) {
					linked.add(symbol);
				}
			}
		}
		return linked;
	}

	public boolean isDiscovery() {
		return discovery;
	}

	/**
	 * Everything the discovery pass learned that the real pass needs before
	 * its first file builds : the export table (a provider's offset is
	 * known whatever the declaration order), but also the build-time half of
	 * the placement picture — pageset members are placed and declared
	 * exclusive as each set is BUILT, and the multi-provider election needs
	 * the whole family to tell which provider a consumer can reach. Without
	 * it, a consumer built before a later set saw that set's members as plain
	 * reachable direntries and refused a resolution the finished picture
	 * allows.
	 */
	public static class Harvest {
		final Map<String, LinkedHashMap<String, Export>> exports;
		final Map<String, Placement> placements;
		final Map<String, String> conflicts;
		final Map<String, String[]> exclusive;

		Harvest(Map<String, LinkedHashMap<String, Export>> exports,
				Map<String, Placement> placements,
				Map<String, String> conflicts,
				Map<String, String[]> exclusive) {
			this.exports = exports;
			this.placements = placements;
			this.conflicts = conflicts;
			this.exclusive = exclusive;
		}
	}

	public Harvest snapshot() {
		Map<String, LinkedHashMap<String, Export>> exportsCopy = new LinkedHashMap<String, LinkedHashMap<String, Export>>();
		for (Map.Entry<String, LinkedHashMap<String, Export>> e : exports.entrySet()) {
			exportsCopy.put(e.getKey(), new LinkedHashMap<String, Export>(e.getValue()));
		}
		return new Harvest(exportsCopy,
				new LinkedHashMap<String, Placement>(placements),
				new LinkedHashMap<String, String>(conflicts),
				new LinkedHashMap<String, String[]>(exclusive));
	}

	public void preseed(Harvest discovered) {
		for (Map.Entry<String, LinkedHashMap<String, Export>> e : discovered.exports.entrySet()) {
			LinkedHashMap<String, Export> byProvider = exports.get(e.getKey());
			if (byProvider == null) {
				byProvider = new LinkedHashMap<String, Export>();
				exports.put(e.getKey(), byProvider);
			}
			byProvider.putAll(e.getValue());
		}
		// placements the real pass has not made yet — the pass re-records each
		// one identically as it builds ; a real conflict still surfaces, since
		// place() compares destinations whatever their origin
		for (Map.Entry<String, Placement> e : discovered.placements.entrySet()) {
			if (!placements.containsKey(e.getKey()) && !conflicts.containsKey(e.getKey())) {
				placements.put(e.getKey(), e.getValue());
			}
		}
		for (Map.Entry<String, String> e : discovered.conflicts.entrySet()) {
			placeConflict(e.getKey(), e.getValue());
		}
		exclusive.putAll(discovered.exclusive);
	}

	/** the absolute value a static 16 bit reference to this symbol resolves to */
	public int resolve(String symbol) throws Exception {
		Export export = electProvider(symbol, currentConsumer);
		if (export.absolute) {
			return export.value;
		}
		return placementOf(export.file, symbol).address + export.value;
	}

	/**
	 * The provider a static reference binds to, for a given consumer.
	 *
	 * One provider : trivial. Several — run-time alternatives sharing a name,
	 * each stage exporting its wave — and the answer depends on WHO asks : the
	 * loader would resolve against whichever alternative is in memory with the
	 * consumer, so the bake must bind to the one provider the consumer can
	 * ever see. A provider is unreachable from the consumer when it is itself
	 * an alternative of the consumer, or when every scene that loads it also
	 * loads an alternative of the consumer (loading that scene evicted the
	 * consumer first). If more than one reachable provider remains, no single
	 * build-time value exists and the reference must stay load-time linked —
	 * refused loudly, never resolved against whichever registered last.
	 */
	private Export electProvider(String symbol, String consumer) throws Exception {
		LinkedHashMap<String, Export> byProvider = exports.get(symbol);
		if (byProvider == null || byProvider.isEmpty()) {
			throw new Exception("no file of this target exports '" + symbol
					+ "' — or the discovery pass stopped before its provider was built,"
					+ " in which case declaring the provider before its consumer works around it");
		}
		if (byProvider.size() == 1) {
			return byProvider.values().iterator().next();
		}
		// identical absolute constants are one value whoever provides it
		Export first = byProvider.values().iterator().next();
		boolean allSameAbsolute = first.absolute;
		for (Export e : byProvider.values()) {
			if (!e.absolute || e.value != first.value) {
				allSameAbsolute = false;
				break;
			}
		}
		if (allSameAbsolute) {
			return first;
		}
		java.util.List<Export> reachable = new java.util.ArrayList<Export>();
		for (Export e : byProvider.values()) {
			if (consumer == null || !unreachableFrom(consumer, e.file)) {
				reachable.add(e);
			}
		}
		if (reachable.size() == 1) {
			return reachable.get(0);
		}
		throw new Exception("'" + symbol + "' is exported by " + byProvider.keySet()
				+ ", run-time alternatives that "
				+ (consumer == null ? "no consumer was named to disambiguate"
						: "'" + consumer + "' could see either of")
				+ " — the reference must stay load-time linked");
	}

	/**
	 * Whether {@code provider} can never be in the loader's index while
	 * {@code consumer} is : either the two are direct alternatives, or every
	 * scene that brings the provider in also brings an alternative of the
	 * consumer — so reaching the provider means the consumer was evicted.
	 */
	private boolean unreachableFrom(String consumer, String provider) {
		if (sameSingleDestination(consumer, provider)) {
			return true;
		}
		java.util.List<String> carriers = new java.util.ArrayList<String>();
		String[] set = exclusive.get(provider);
		for (Map.Entry<String, java.util.LinkedHashSet<String>> scene : sceneLoads.entrySet()) {
			if (scene.getValue().contains(provider)
					|| (set != null && scene.getValue().contains(set[1]))) {
				carriers.add(scene.getKey());
			}
		}
		if (carriers.isEmpty()) {
			return false; // nothing says how the provider gets in : assume reachable
		}
		for (String scene : carriers) {
			boolean evictsConsumer = false;
			for (String load : sceneLoads.get(scene)) {
				if (!load.equals(consumer) && sameSingleDestination(consumer, load)) {
					evictsConsumer = true;
					break;
				}
			}
			if (!evictsConsumer) {
				return false; // this scene can add the provider next to the consumer
			}
		}
		return true;
	}

	/**
	 * The address a file is loaded at.
	 *
	 * What an internal reference needs to be baked : a unit's own references
	 * are relative to where it lands, and a scene-placed file lands
	 * somewhere the builder already knows.
	 */
	public int addressOf(String file) throws Exception {
		return placementOf(file, file).address;
	}

	/** the page a static reference to <file>$PAGE resolves to */
	public int resolvePage(String file) throws Exception {
		return placementOf(file, file + "$PAGE").page;
	}

	/**
	 * The page the object exporting this symbol was placed on.
	 *
	 * A generator that emits a page byte per entry — a tilemap, an object
	 * index — asks here rather than baking one {@code <file>$PAGE} for the
	 * whole table. For an ordinary file the answer is simply its region's
	 * page ; for a member of a multi-page set it is the page that member
	 * landed on, which is the whole point of the question.
	 */
	public int pageOf(String symbol) throws Exception {
		Export export = electProvider(symbol, currentConsumer);
		return placementOf(export.file, symbol).page;
	}

	private Placement placementOf(String file, String symbol) throws Exception {
		String conflict = conflicts.get(file);
		if (conflict != null) {
			throw new Exception("'" + symbol + "' comes from '" + file
					+ "', which is not at a single destination : " + conflict);
		}
		Placement placement = placements.get(file);
		if (placement == null) {
			throw new Exception("'" + symbol + "' comes from '" + file
					+ "', which no scene loads at a fixed destination");
		}
		return placement;
	}

	/** file -> {exclusion group, owner within it} for pageset members */
	private final Map<String, String[]> exclusive = new LinkedHashMap<String, String[]>();

	/**
	 * Records that a file is a member of a set that occupies a region as a
	 * whole.
	 *
	 * A pageset's members are loaded and evicted together — a scene names the
	 * set, never a member — so two sets targeting the same region are
	 * alternatives however their packing turned out. Which page a given item
	 * landed on differs between them, so destination alone cannot say it.
	 *
	 * @param group the region the sets compete for
	 * @param owner the set this file belongs to ; members of the same set
	 *              ARE loaded together, and stay subject to plain uniqueness
	 */
	public void declareExclusive(String file, String group, String owner) {
		exclusive.put(file, new String[] { group, owner });
	}

	/**
	 * Whether two direntries are alternatives, so never both in the loader's
	 * index : either at the same single destination — loading one evicts the
	 * other — or members of different sets competing for the same region.
	 */
	public boolean sameSingleDestination(String a, String b) {
		String[] ea = exclusive.get(a);
		String[] eb = exclusive.get(b);
		if (ea != null && eb != null && ea[0].equals(eb[0]) && !ea[1].equals(eb[1])) {
			return true;
		}
		Placement pa = placements.get(a);
		Placement pb = placements.get(b);
		return pa != null && pb != null && pa.page == pb.page && pa.address == pb.address;
	}

	/** a region whose alternatives promise the same run-time face */
	public void declareInterfaceRegion(String name, int page, int address) {
		interfaceRegions.put(name, new int[] { page, address });
	}

	/**
	 * The interface check, run once the target is built : every file loaded
	 * at an interface region must emit the same export list. The engine keeps
	 * EXTERNAL references to those names across swaps — an alternative missing
	 * one would leave them silently resolved to zero.
	 *
	 * @param unitExports file -> sorted names its link data emits, as
	 *                    collected by the link symbol table during the build
	 */
	public void checkInterfaces(Map<String, java.util.TreeSet<String>> unitExports) throws Exception {
		for (Map.Entry<String, int[]> region : interfaceRegions.entrySet()) {
			String dest = destKey(region.getValue()[0], region.getValue()[1]);
			String reference = null;
			java.util.TreeSet<String> referenceList = null;
			for (Map.Entry<String, java.util.LinkedHashSet<String>> entry : allDestinations.entrySet()) {
				if (!entry.getValue().contains(dest)) {
					continue;
				}
				if (entry.getValue().size() > 1) {
					throw new Exception("region '" + region.getKey() + "' is an interface :"
							+ " its alternatives are mutually exclusive by destination, but '"
							+ entry.getKey() + "' is also loaded elsewhere ("
							+ entry.getValue() + ") — it would coexist with them");
				}
				java.util.TreeSet<String> list = unitExports.get(entry.getKey());
				if (list == null) {
					list = new java.util.TreeSet<String>();
				}
				if (reference == null) {
					reference = entry.getKey();
					referenceList = list;
					continue;
				}
				if (!referenceList.equals(list)) {
					throw new Exception("region '" + region.getKey() + "' is an interface :"
							+ " its alternatives must emit the same export list, but '"
							+ reference + "' emits " + referenceList + " while '"
							+ entry.getKey() + "' emits " + list);
				}
			}
		}
	}

	private static String destKey(int page, int address) {
		return String.format("page %d $%04X", page, address);
	}

	public void clear() {
		placements.clear();
		conflicts.clear();
		exports.clear();
		sceneLoads.clear();
		interfaceRegions.clear();
		allDestinations.clear();
		exclusive.clear();
		candidates.clear();
		discovery = false;
		currentConsumer = null;
	}
}
