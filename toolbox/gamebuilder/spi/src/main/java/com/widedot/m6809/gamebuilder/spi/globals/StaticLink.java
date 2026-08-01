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
 *    it runs, so declaration order does not matter for placements. A direntry
 *    loaded at two different destinations is recorded as conflicting, and any
 *    static reference to it becomes a build error — never a silent fallback :
 *    the section name is a promise, breaking it has to be heard.
 *
 *  - at which offset inside its direntry a symbol sits. Known only once the
 *    provider is assembled, so it is registered as each direntry is built —
 *    which is why a provider consumed statically must be declared before its
 *    consumer in the configuration.
 *
 * What this cannot see : a game loading a file at a run-time computed address
 * through the loader's API. The section marker is the author's assertion that
 * the referenced content is scene-placed only ; the builder verifies it
 * against everything declared.
 */
public class StaticLink {

	/** where a direntry is loaded, according to the scenes of the target */
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

	/** a symbol some direntry exports, at an offset inside its binary */
	public static class Export {
		public final String direntry;
		public final int value;
		/** a constant-section export : the value stands alone, no placement */
		public final boolean absolute;

		public Export(String direntry, int value, boolean absolute) {
			this.direntry = direntry;
			this.value = value;
			this.absolute = absolute;
		}
	}

	private final Map<String, Placement> placements = new LinkedHashMap<String, Placement>();
	/** direntry -> why it cannot be resolved statically */
	private final Map<String, String> conflicts = new LinkedHashMap<String, String>();
	private final Map<String, Export> exports = new LinkedHashMap<String, Export>();
	/** interface region name -> its destination ; declared with interface="true" */
	private final Map<String, int[]> interfaceRegions = new LinkedHashMap<String, int[]>();
	/**
	 * direntry -> every destination any scene gives it, kept even when they
	 * conflict : the interface check must see a member that also loads
	 * elsewhere, which the single-placement map forgets.
	 */
	private final Map<String, java.util.LinkedHashSet<String>> allDestinations = new LinkedHashMap<String, java.util.LinkedHashSet<String>>();

	/** record where a scene loads a direntry ; a second, different destination turns into a conflict */
	public void place(String direntry, int page, int address, String scene) {
		java.util.LinkedHashSet<String> dests = allDestinations.get(direntry);
		if (dests == null) {
			dests = new java.util.LinkedHashSet<String>();
			allDestinations.put(direntry, dests);
		}
		dests.add(destKey(page, address));
		if (conflicts.containsKey(direntry)) {
			return;
		}
		Placement known = placements.get(direntry);
		if (known == null) {
			placements.put(direntry, new Placement(page, address, scene));
			return;
		}
		if (known.page != page || known.address != address) {
			conflicts.put(direntry, String.format(
					"loaded at page %d $%04X by scene %s, but at page %d $%04X by scene %s",
					known.page, known.address, known.scene, page, address, scene));
			placements.remove(direntry);
		}
	}

	/** record a destination that cannot serve static references, with the reason */
	public void placeConflict(String direntry, String reason) {
		if (!conflicts.containsKey(direntry)) {
			conflicts.put(direntry, reason);
			placements.remove(direntry);
		}
	}

	public void registerExport(String symbol, String direntry, int value, boolean absolute) {
		// duplicate exports across a target are rejected by the link symbol
		// table already ; last one wins here without further ceremony
		exports.put(symbol, new Export(direntry, value, absolute));
	}

	/** the absolute value a static 16 bit reference to this symbol resolves to */
	public int resolve(String symbol) throws Exception {
		Export export = exports.get(symbol);
		if (export == null) {
			throw new Exception("no direntry built so far exports '" + symbol
					+ "' — a provider consumed statically must be declared before its consumer");
		}
		if (export.absolute) {
			return export.value;
		}
		return placementOf(export.direntry, symbol).address + export.value;
	}

	/** the page a static reference to <direntry>$PAGE resolves to */
	public int resolvePage(String direntry) throws Exception {
		return placementOf(direntry, direntry + "$PAGE").page;
	}

	private Placement placementOf(String direntry, String symbol) throws Exception {
		String conflict = conflicts.get(direntry);
		if (conflict != null) {
			throw new Exception("'" + symbol + "' comes from '" + direntry
					+ "', which is not at a single destination : " + conflict);
		}
		Placement placement = placements.get(direntry);
		if (placement == null) {
			throw new Exception("'" + symbol + "' comes from '" + direntry
					+ "', which no scene loads at a fixed destination");
		}
		return placement;
	}

	/**
	 * Whether two direntries are alternatives : each one at a single known
	 * destination, and the same one. Loading either evicts the other from the
	 * loader's index, so they never coexist at run time.
	 */
	public boolean sameSingleDestination(String a, String b) {
		Placement pa = placements.get(a);
		Placement pb = placements.get(b);
		return pa != null && pb != null && pa.page == pb.page && pa.address == pb.address;
	}

	/** a region whose alternatives promise the same run-time face */
	public void declareInterfaceRegion(String name, int page, int address) {
		interfaceRegions.put(name, new int[] { page, address });
	}

	/**
	 * The interface check, run once the target is built : every direntry loaded
	 * at an interface region must emit the same export list. The engine keeps
	 * EXTERNAL references to those names across swaps — an alternative missing
	 * one would leave them silently resolved to zero.
	 *
	 * @param unitExports direntry -> sorted names its link data emits, as
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
		interfaceRegions.clear();
		allDestinations.clear();
	}
}
