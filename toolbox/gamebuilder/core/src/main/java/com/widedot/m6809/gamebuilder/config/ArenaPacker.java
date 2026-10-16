package com.widedot.m6809.gamebuilder.config;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.globals.Compositions;
import com.widedot.m6809.gamebuilder.spi.globals.Cuts;
import com.widedot.m6809.gamebuilder.spi.globals.Regions;

import lombok.extern.slf4j.Slf4j;

/**
 * Ranges the files of an arena over its zones.
 *
 * An arena is a named list of zones that the author offers to the builder :
 * "here is room, put them where you like". What the builder decides is
 * published per file — {@code <file>.page} and {@code <file>.address} — because
 * an arena's content is reached through a table, never through a baked address.
 *
 * <p><b>One packing per arena, all scenes together.</b> A file loaded by any
 * scene into the arena gets its own place, and nothing in an arena ever
 * overlaps anything else in the same arena. Two sets of resources that take
 * turns on the same RAM — a family of levels and a title screen — are two
 * arenas declaring the same zones : the layout allows contenders to overlap.
 *
 * <p><b>And the packer knows who may not overlap whom.</b> When the
 * configuration declares its RAM states, a file is placed on bytes no
 * CO-RESIDENT file already holds — co-resident meaning some {@code
 * <composition>} holds them both. What used to be a refusal after the fact
 * becomes a placement that avoids the collision : the packer starts a zone
 * after whatever conflicting content already sits at its head, and only a
 * genuine lack of room stops the build. Files at a fixed destination (a
 * region, a literal page and address) are counted too — they are exactly the
 * content an arena's zone can grow into without anyone noticing.
 *
 * <p>Declare no state and nothing changes : with no composition, no two files
 * are known to be co-resident, every zone starts at its head, and the packing
 * is the one that produced every image before this.
 *
 * <p><b>One sort, whole if it fits, cut if it cannot</b> (author's decision,
 * 11/08). Every file — divisible or not — joins a single largest-first sort.
 * A file that fits a zone's free run is placed whole and keeps its name. A
 * file that does not fit and whose elements the builder knows (a collection :
 * every top-level child can name its parts) FLOWS into the free tails, one
 * member per tail used — cutting is a fallback, not a policy : where the
 * build used to stop on "the arena cannot hold X", it now ranges. Largest
 * first is what reaches the theoretical page count instead of wasting one
 * page in three (measured on r-type : 8 pages against 12) ; ties keep
 * declaration order, so a build stays reproducible.
 *
 * <p><b>Holes, when no tail holds a file</b> (12/10/2026). A zone's tail
 * starts after the highest conflicting content, so the room under it — what
 * another arena's files hold in states this file is never part of — was
 * lost : Sonic 2's Aquatic Ruin 2 stopped on a full arena with 14 KB free in
 * one of its pages, under Chemical Plant's objects. A file no tail holds,
 * and that cannot be cut, now takes the lowest free run of a zone below its
 * tail : free of every file of its own arena and of every file a state holds
 * with it. Only where the build used to stop : every packing that fitted
 * stays the same.
 */
@Slf4j
public final class ArenaPacker {

	/**
	 * A free tail smaller than this is left empty rather than crumbling a
	 * collection into it : a member costs a directory entry, a scene table
	 * entry and a load call, and a small block compresses badly. The manual's
	 * "seuil de creux" — a setting some day, a sane constant until someone
	 * needs to tune it.
	 */
	private static final int GAP_MIN = 256;

	/** a divisible file, measured : its parts, their sizes, its generation dir */
	public static class Divisible {
		public final List<String[]> parts;
		public final int[] sizes;
		public final String gendir;
		/** the <unit> nodes among the parts, by part index — see Cuts.Cut */
		public final Map<Integer, ImmutableNode> units;
		public final int total;

		public Divisible(List<String[]> parts, int[] sizes, String gendir,
				Map<Integer, ImmutableNode> units) {
			this.parts = parts;
			this.sizes = sizes;
			this.gendir = gendir;
			this.units = units;
			int sum = 0;
			for (int s : sizes) {
				sum += s;
			}
			this.total = sum;
		}
	}

	private ArenaPacker() {
	}

	/**
	 * Decide where every arena-bound file lands, and record it in the context.
	 * Idempotent : both the placement scan and the scene plugin resolve the
	 * same target and must see the same answer.
	 *
	 * @param target the target node, walked for its scene loads
	 * @param regions the resolved layout
	 * @param divisibles the collections the scan measured, by file name
	 */
	public static void pack(ImmutableNode target, BuildContext ctx,
			Map<String, Regions.Region> regions,
			Map<String, Divisible> divisibles) throws Exception {

		// file order per arena, as the scenes declare them
		Map<String, List<String>> wanted = new LinkedHashMap<String, List<String>>();
		collect(target, ctx, wanted);
		if (wanted.isEmpty()) {
			return;
		}

		// who may not overlap whom, and what is already spoken for
		Map<String, Set<String>> statesOf = statesOf(target, ctx);
		List<Placed> taken = fixedPlacements(target, ctx, regions);

		// the RAM states declared : file by file (16/10/2026, the default
		// once a layout says which files share a state) ; the discovery
		// pass keeps the arenas' provisional layout
		if (!statesOf.isEmpty() && measured(wanted, ctx, divisibles)) {
			packFiles(wanted, regions, ctx, divisibles, statesOf, taken);
			return;
		}

		for (Map.Entry<String, List<String>> e : wanted.entrySet()) {
			Regions.Region arena = regions.get(e.getKey());
			if (arena == null) {
				throw new Exception("unknown arena '" + e.getKey() + "' (layout declares: "
						+ regions.keySet() + ")");
			}
			place(arena, e.getValue(), ctx, divisibles, statesOf, taken);
		}
	}

	/** every arena file measured : the discovery pass is over */
	private static boolean measured(Map<String, List<String>> wanted, BuildContext ctx,
			Map<String, Divisible> divisibles) {
		for (List<String> files : wanted.values()) {
			for (String f : files) {
				if (!divisibles.containsKey(f) && ctx.regions.fileSize(f) == null) {
					return false;
				}
			}
		}
		return true;
	}

	/** a run of free bytes in a zone, for one file */
	static final class Run {
		final Regions.Zone zone;
		final int at;
		final int size;

		Run(Regions.Zone zone, int at, int size) {
			this.zone = zone;
			this.at = at;
			this.size = size;
		}
	}

	/**
	 * Packing file by file (15/10/2026), whenever the layout declares its
	 * RAM states (the {@code <composition>}s ; 16/10/2026 : no setting, the
	 * arena packing kept for a layout without them, where nothing says which
	 * files may share bytes).
	 * Every arena's files in one sort : the most shared first (the count of
	 * states that hold the file), then the largest, ties in the scenes'
	 * order ; a file takes the lowest free run of its arena's zones, in their
	 * order, that no file it shares a state with holds : its own conflicts,
	 * not its arena's. Packing an arena as a whole starts
	 * each zone after the highest content ANY of its files shares a state
	 * with, and an arena whose files live in several states leaves the room
	 * of the others to nobody — Sonic 2's Hidden Palace 1, 32 KB free in its
	 * state, could not hold 383 bytes more. The most shared first
	 * (16/10/2026) : sorted by size alone, the files every state holds came
	 * after the bigger ones of single acts, above the highest of them page by
	 * page, and cut every state's free room (Sonic 2's largest free run, 16 KB
	 * in most states, down to 9 KB) ; packed arena after arena, a big file of
	 * an arena packed late found no run (Sonic 2's boss arena, 15 KB). The
	 * most shared first keep together at the bottom, each state's room on top
	 * of them, and the files of one state, the least constrained, share one
	 * largest-first sort. A collection no run holds whole
	 * flows into the runs, one member per run. A file no composition holds
	 * conflicts with everything.
	 */
	static void packFiles(Map<String, List<String>> wanted, Map<String, Regions.Region> regions,
			BuildContext ctx, Map<String, Divisible> divisibles, Map<String, Set<String>> statesOf,
			List<Placed> taken) throws Exception {
		final List<String> order = new ArrayList<String>();
		final Map<String, String> arenaOf = new LinkedHashMap<String, String>();
		final Map<String, Integer> sizes = new LinkedHashMap<String, Integer>();
		for (Map.Entry<String, List<String>> e : wanted.entrySet()) {
			if (regions.get(e.getKey()) == null) {
				throw new Exception("unknown arena '" + e.getKey() + "' (layout declares: "
						+ regions.keySet() + ")");
			}
			for (String f : e.getValue()) {
				if (arenaOf.containsKey(f)) {
					continue;
				}
				arenaOf.put(f, e.getKey());
				order.add(f);
				Divisible d = divisibles.get(f);
				sizes.put(f, d != null ? d.total : ctx.regions.fileSize(f));
			}
		}
		// the most shared first, then the largest
		final List<String> declared = new ArrayList<String>(order);
		order.sort(Comparator.comparingInt((String f) -> -shared(f, statesOf))
				.thenComparingInt((String f) -> -sizes.get(f))
				.thenComparingInt(declared::indexOf));
		for (String f : order) {
			Regions.Region arena = regions.get(arenaOf.get(f));
			int need = sizes.get(f);
			List<Run> runs = freeRuns(arena, f, statesOf, taken);
			Divisible d = divisibles.get(f);
			Run fit = null;
			int biggest = 0;
			for (Run r : runs) {
				biggest = Math.max(biggest, r.size);
				if (fit == null && r.size >= need) {
					fit = r;
				}
			}
			if (fit != null) {
				ctx.regions.placeFile(f, fit.zone.page, fit.at);
				taken.add(new Placed(f, fit.zone.page, fit.at, need, fit.zone.slice));
				if (d != null) {
					List<Integer> all = new ArrayList<Integer>();
					for (int i = 0; i < d.parts.size(); i++) {
						all.add(i);
					}
					List<List<Integer>> one = new ArrayList<List<Integer>>();
					one.add(all);
					ctx.cuts.declare(f, new Cuts.Cut(d.parts, one, d.gendir, d.units));
				}
				log.debug("arena {} : {} -> page {} ${}", arena.name, f, fit.zone.page,
						Integer.toHexString(fit.at).toUpperCase());
				continue;
			}
			if (d == null) {
				throw new Exception("arena '" + arena.name + "' cannot hold '" + f + "' : it needs "
						+ need + " bytes in one run free of the files it shares a state with, the"
						+ " roomiest has " + biggest + " — give the arena another <zone>, or make"
						+ " the file smaller");
			}
			cutRuns(arena, f, d, runs, ctx, taken);
		}
	}

	/** how many states hold a file ; one no composition holds, first of all */
	static int shared(String f, Map<String, Set<String>> statesOf) {
		Set<String> s = statesOf.get(f);
		return s == null ? Integer.MAX_VALUE : s.size();
	}

	/**
	 * The free runs of an arena's zones for one file, in the zones' order and
	 * by address : the bytes no placed file it shares a state with holds.
	 */
	static List<Run> freeRuns(Regions.Region arena, String f, Map<String, Set<String>> statesOf,
			List<Placed> taken) {
		Set<String> ours = statesOf.get(f);
		List<Run> runs = new ArrayList<Run>();
		for (Regions.Zone z : arena.zones) {
			List<int[]> busy = new ArrayList<int[]>();
			for (Placed p : taken) {
				if (p.page != z.page || p.address + p.size <= z.address || p.address >= z.end()) {
					continue;
				}
				if (p.slice != null && z.slice != null && !p.slice.equals(z.slice)) {
					continue;
				}
				Set<String> theirs = statesOf.get(p.file);
				boolean conflicts = ours == null || theirs == null;
				if (!conflicts) {
					for (String state : ours) {
						if (theirs.contains(state)) {
							conflicts = true;
							break;
						}
					}
				}
				if (conflicts) {
					busy.add(new int[] { p.address, p.address + p.size });
				}
			}
			busy.sort(Comparator.comparingInt((int[] b) -> b[0]));
			int at = z.address;
			for (int[] b : busy) {
				if (b[0] > at) {
					runs.add(new Run(z, at, b[0] - at));
				}
				at = Math.max(at, b[1]);
			}
			if (z.end() > at) {
				runs.add(new Run(z, at, z.end() - at));
			}
		}
		return runs;
	}

	/**
	 * A collection no run holds whole, flowed into the runs in element order :
	 * one member per run used, runs under {@link #GAP_MIN} left empty.
	 */
	static void cutRuns(Regions.Region arena, String file, Divisible d, List<Run> runs,
			BuildContext ctx, List<Placed> taken) throws Exception {
		int biggest = 0;
		for (Run r : runs) {
			biggest = Math.max(biggest, r.size);
		}
		List<Cuts.Member> members = new ArrayList<Cuts.Member>();
		List<List<Integer>> chunks = new ArrayList<List<Integer>>();
		int ri = 0;
		int used = 0;
		List<Integer> chunk = new ArrayList<Integer>();
		for (int e = 0; e < d.sizes.length; e++) {
			if (d.sizes[e] > biggest) {
				throw new Exception("collection '" + file + "' : '" + d.parts.get(e)[1] + "' is "
						+ d.sizes[e] + " bytes, more than the " + biggest
						+ " bytes of the roomiest free run — an element is never split, it has"
						+ " to be made smaller (or the arena needs a roomier zone)");
			}
			while (ri < runs.size()
					&& (runs.get(ri).size < GAP_MIN || used + d.sizes[e] > runs.get(ri).size)) {
				if (!chunk.isEmpty()) {
					closeRun(arena, file, members, chunks, chunk, runs.get(ri), used, taken);
					chunk = new ArrayList<Integer>();
				}
				ri++;
				used = 0;
			}
			if (ri == runs.size()) {
				int remaining = 0;
				for (int r = e; r < d.sizes.length; r++) {
					remaining += d.sizes[r];
				}
				throw new Exception("collection '" + file + "' does not fit : " + remaining
						+ " bytes of elements remain and every free run is used — give the"
						+ " arena another <zone>, or put less in the collection");
			}
			chunk.add(e);
			used += d.sizes[e];
		}
		if (!chunk.isEmpty()) {
			closeRun(arena, file, members, chunks, chunk, runs.get(ri), used, taken);
		}
		if (members.size() == 1) {
			ctx.regions.placeFile(file, members.get(0).page, members.get(0).address);
			ctx.cuts.declare(file, new Cuts.Cut(d.parts, chunks, d.gendir, d.units));
		} else {
			ctx.cuts.declare(file, new Cuts.Cut(d.parts, chunks, d.gendir, d.units, members));
		}
		log.info("collection {} : {} member(s) flowed into arena '{}'", file, members.size(),
				arena.name);
	}

	private static void closeRun(Regions.Region arena, String file, List<Cuts.Member> members,
			List<List<Integer>> chunks, List<Integer> chunk, Run run, int used, List<Placed> taken) {
		taken.add(new Placed(file, run.zone.page, run.at, used, run.zone.slice));
		String memberName = file + "." + members.size();
		members.add(new Cuts.Member(memberName, run.zone.page, run.at));
		chunks.add(new ArrayList<Integer>(chunk));
		log.debug("arena {} : {} -> page {} ${} ({} elements)", arena.name, memberName,
				run.zone.page, Integer.toHexString(run.at).toUpperCase(), chunk.size());
	}

	/** one file already sitting somewhere, and who put it there */
	static final class Placed {
		final String file;
		final int page;
		final int address;
		final int size;
		/**
		 * Which slice of the page, when the window shows less than one — null
		 * when the window shows a whole page, or when the declaration did not
		 * say (a bare page/address place). Two contents on the same page but
		 * DIFFERENT slices never share a byte : without this the packer read
		 * them as one and started an arena after content it does not touch.
		 */
		final Integer slice;

		Placed(String file, int page, int address, int size) {
			this(file, page, address, size, null);
		}

		Placed(String file, int page, int address, int size, Integer slice) {
			this.file = file;
			this.page = page;
			this.address = address;
			this.size = size;
			this.slice = slice;
		}
	}

	/**
	 * file -> the states that hold it. Two files conflict when a state holds
	 * both ; with no composition declared the map is empty and nothing
	 * conflicts, which is the packing every image before this was built with.
	 */
	private static Map<String, Set<String>> statesOf(ImmutableNode target, BuildContext ctx)
			throws Exception {
		Map<String, Set<String>> states = new LinkedHashMap<String, Set<String>>();
		ImmutableNode layout = layoutOf(target);
		if (layout == null) {
			return states;
		}
		Map<String, List<String>> scenes = new LinkedHashMap<String, List<String>>();
		collectScenes(target, ctx, scenes);
		for (Compositions.Composition c
				: com.widedot.m6809.gamebuilder.config.CompositionScan.parse(layout, ctx)) {
			for (String scene : c.scenes) {
				for (String file : scenes.getOrDefault(scene, new ArrayList<String>())) {
					states.computeIfAbsent(file, f -> new LinkedHashSet<String>()).add(c.name);
				}
			}
		}
		return states;
	}

	private static ImmutableNode layoutOf(ImmutableNode node) {
		if ("layout".equals(node.getNodeName())) {
			return node;
		}
		for (ImmutableNode child : node.getChildren()) {
			ImmutableNode found = layoutOf(child);
			if (found != null) {
				return found;
			}
		}
		return null;
	}

	private static void collectScenes(ImmutableNode node, BuildContext ctx,
			Map<String, List<String>> scenes) throws Exception {
		if ("scene".equals(node.getNodeName())) {
			String name = Attribute.getStringOpt(node, ctx, "name");
			if (name != null) {
				List<String> files = scenes.computeIfAbsent(name, s -> new ArrayList<String>());
				for (ImmutableNode load : node.getChildren()) {
					if ("load".equals(load.getNodeName())) {
						String file = Attribute.getStringOpt(load, ctx, "name");
						if (file != null) {
							files.add(file);
						}
					}
				}
			}
			return;
		}
		for (ImmutableNode child : node.getChildren()) {
			collectScenes(child, ctx, scenes);
		}
	}

	/**
	 * What already has a destination the packer does not choose : a file in a
	 * region, or one naming its page and address outright. An arena's zone can
	 * grow into exactly that content — measured on r-type, where a stage's
	 * terrain collision outgrew the boundary the common was placed against.
	 */
	private static List<Placed> fixedPlacements(ImmutableNode target, BuildContext ctx,
			Map<String, Regions.Region> regions) throws Exception {
		List<Placed> taken = new ArrayList<Placed>();
		Map<String, List<String>> scenes = new LinkedHashMap<String, List<String>>();
		collectScenes(target, ctx, scenes);
		Set<String> seen = new LinkedHashSet<String>();
		for (List<String> files : scenes.values()) {
			for (String file : files) {
				if (!seen.add(file)) {
					continue;
				}
				com.widedot.m6809.gamebuilder.spi.globals.FilePlaces.Place place =
						ctx.filePlaces.get(file);
				if (place == null || place.arena != null) {
					continue;                     // the packer places those itself
				}
				Integer size = ctx.regions.fileSize(file);
				if (size == null || size <= 0) {
					continue;                     // not measured yet : discovery pass
				}
				if (place.region != null) {
					Regions.Region r = regions.get(place.region);
					if (r != null && !r.zones.isEmpty()) {
						// The region's FIRST zone : where a load into it lands.
						// A region spanning several pages holds one file per
						// page (that is what the page count is for), and which
						// page a given file takes is decided by the cut, not
						// known here — so on such a region this claims the head
						// page only. It over-claims there (harmless : the packer
						// merely starts later) and under-claims on the others,
						// where CompositionChecks stays the backstop : it reads
						// the real destinations back from the RAM map and
						// refuses an overlap the packer did not avoid.
						Regions.Zone z = r.zones.get(0);
						taken.add(new Placed(file, z.page, z.address, size, z.slice));
					}
					continue;
				}
				if (place.page != null && place.address != null) {
					taken.add(new Placed(file, place.page, place.address, size));
				}
			}
		}
		return taken;
	}

	/**
	 * Where a zone may start for this arena : after the highest CONFLICTING
	 * content already placed inside it. Non-conflicting content is left behind
	 * — alternatives are exactly what a shared zone is for.
	 */
	private static int start(Regions.Zone z, List<String> arenaFiles,
			Map<String, Set<String>> statesOf, List<Placed> taken) {
		int at = z.address;
		if (statesOf.isEmpty()) {
			return at;
		}
		for (Placed p : taken) {
			if (p.page != z.page || p.address + p.size <= z.address || p.address >= z.end()) {
				continue;
			}
			// Même page, adresses qui se croisent — mais deux TRANCHES
			// différentes d'une page ne partagent aucun octet : la fenêtre
			// vidéo en montre 8 Ko sur 16, et ce qui vit dans l'autre moitié
			// n'est pas là. Sans ce test, un tas placé dans une tranche
			// repoussait le début d'une arène déclarée dans l'autre.
			if (p.slice != null && z.slice != null && !p.slice.equals(z.slice)) {
				continue;
			}
			Set<String> theirs = statesOf.get(p.file);
			if (theirs == null) {
				continue;
			}
			boolean conflicts = false;
			for (String f : arenaFiles) {
				Set<String> ours = statesOf.get(f);
				if (ours == null) {
					continue;
				}
				for (String state : ours) {
					if (theirs.contains(state)) {
						conflicts = true;
						break;
					}
				}
				if (conflicts) {
					break;
				}
			}
			if (conflicts) {
				at = Math.max(at, p.address + p.size);
			}
		}
		return Math.min(at, z.end());
	}

	private static void collect(ImmutableNode node, BuildContext ctx,
			Map<String, List<String>> wanted) throws Exception {
		if ("load".equals(node.getNodeName())) {
			String name = Attribute.getStringOpt(node, ctx, "name");
			if (name == null) {
				return; // malformed loads are the scene plugin's report
			}
			// a load is a name : it joins the arena its file declared, if any
			// (per-load destinations are gone, 4c)
			String arena = null;
			com.widedot.m6809.gamebuilder.spi.globals.FilePlaces.Place attributed =
					ctx.filePlaces.get(name);
			if (attributed != null) {
				arena = attributed.arena;
			}
			if (arena != null) {
				List<String> files = wanted.computeIfAbsent(arena, k -> new ArrayList<String>());
				if (!files.contains(name)) {
					files.add(name);    // a file loaded by two scenes is placed once
				}
			}
		}
		for (ImmutableNode child : node.getChildren()) {
			collect(child, ctx, wanted);
		}
	}

	private static void place(Regions.Region arena, List<String> files, BuildContext ctx,
			Map<String, Divisible> divisibles, Map<String, Set<String>> statesOf,
			List<Placed> taken) throws Exception {

		// how much room each zone has left, in declaration order — a zone
		// starts after whatever CO-RESIDENT content already sits at its head
		int[] free = new int[arena.zones.size()];
		int[] tailStart = new int[free.length];
		for (int i = 0; i < free.length; i++) {
			Regions.Zone z = arena.zones.get(i);
			tailStart[i] = start(z, files, statesOf, taken);
			free[i] = z.end() - tailStart[i];
		}

		// a collection's size is the sum of its measured elements ; anything
		// else was measured by the discovery pass
		List<String> order = new ArrayList<String>(files);
		final Map<String, Integer> sizes = new LinkedHashMap<String, Integer>();
		boolean measured = true;
		for (String f : files) {
			Divisible d = divisibles.get(f);
			// no ternary here : int alongside Integer would unbox a null size
			Integer s;
			if (d != null) {
				s = d.total;
			} else {
				s = ctx.regions.fileSize(f);
			}
			if (s == null) {
				measured = false;
			}
			sizes.put(f, s == null ? 0 : s);
		}
		if (!measured) {
			// The discovery pass is running and it is what produces the sizes.
			// Lay the files out one after another from the head of the first
			// zone, ignoring its bounds : the addresses are provisional and
			// nothing is built against them, but they must not land on each
			// other — a scene's own writes are checked for overlap, and a pile
			// of files at one address would fail a check that means nothing
			// yet. No refusal either : the pass has to reach the end for
			// anything to be measured at all. Collections are cut against the
			// FULL zones so the id reservation has a member count to work with.
			Regions.Zone head = arena.zones.get(0);
			int at = head.address;
			for (String f : files) {
				Divisible d = divisibles.get(f);
				if (d != null) {
					int[] fullFree = new int[arena.zones.size()];
					for (int i = 0; i < fullFree.length; i++) {
						fullFree[i] = arena.zones.get(i).size;
					}
					cut(arena, f, d, fullFree, ctx);
					continue;
				}
				ctx.regions.placeFile(f, head.page, at);
				Integer known = ctx.regions.fileSize(f);
				at += known == null ? 1 : known;
			}
			return;
		}

		// ONE SORT : largest first, divisible or not ; ties keep the order
		// the scenes declared them in
		final List<String> declared = files;
		order.sort(Comparator
				.comparingInt((String f) -> -sizes.get(f))
				.thenComparingInt(declared::indexOf));

		for (String f : order) {
			int need = sizes.get(f);
			int chosen = -1;
			for (int i = 0; i < free.length; i++) {
				if (free[i] >= need) {
					chosen = i;
					break;
				}
			}
			Divisible d = divisibles.get(f);
			if (chosen >= 0) {
				// whole if it fits — and it keeps its name, whoever it is
				Regions.Zone z = arena.zones.get(chosen);
				int at = z.end() - free[chosen];
				free[chosen] -= need;
				ctx.regions.placeFile(f, z.page, at);
				taken.add(new Placed(f, z.page, at, need));
				if (d != null) {
					// a collection placed whole is still emitted from its
					// parts : one chunk, all elements
					List<Integer> all = new ArrayList<Integer>();
					for (int i = 0; i < d.parts.size(); i++) {
						all.add(i);
					}
					List<List<Integer>> one = new ArrayList<List<Integer>>();
					one.add(all);
					ctx.cuts.declare(f, new Cuts.Cut(d.parts, one, d.gendir, d.units));
				}
				log.debug("arena {} : {} -> page {} ${}", arena.name, f, z.page,
						Integer.toHexString(at).toUpperCase());
				continue;
			}
			if (d == null) {
				// no tail holds it : a hole under a tail, free of everything
				// this file may be in RAM with
				if (hole(arena, f, need, files, tailStart, statesOf, taken, ctx)) {
					continue;
				}
				int biggest = 0;
				for (int r : free) {
					biggest = Math.max(biggest, r);
				}
				throw new Exception("arena '" + arena.name + "' cannot hold '" + f + "' : it needs "
						+ need + " bytes in one run, the roomiest zone has " + biggest
						+ " left — give the arena another <zone>, or make the file smaller");
			}
			// cut if it cannot : the fallback the author asked for
			cut(arena, f, d, free, ctx, taken);
		}
	}

	/**
	 * Place a file whole in the lowest free run under a zone's tail : the
	 * bytes no file of this arena holds and no file a state holds with this
	 * one. False when no run is long enough.
	 */
	static boolean hole(Regions.Region arena, String f, int need, List<String> arenaFiles,
			int[] tailStart, Map<String, Set<String>> statesOf, List<Placed> taken,
			BuildContext ctx) {
		Set<String> ours = statesOf.get(f);
		Set<String> mine = new java.util.HashSet<String>(arenaFiles);
		for (int i = 0; i < tailStart.length; i++) {
			Regions.Zone z = arena.zones.get(i);
			// the busy ranges of this zone, below its tail
			List<int[]> busy = new ArrayList<int[]>();
			for (Placed p : taken) {
				if (p.page != z.page || p.address + p.size <= z.address || p.address >= tailStart[i]) {
					continue;
				}
				if (p.slice != null && z.slice != null && !p.slice.equals(z.slice)) {
					continue;
				}
				boolean conflicts = mine.contains(p.file);
				if (!conflicts && ours != null) {
					Set<String> theirs = statesOf.get(p.file);
					if (theirs != null) {
						for (String state : ours) {
							if (theirs.contains(state)) {
								conflicts = true;
								break;
							}
						}
					}
				}
				if (conflicts) {
					busy.add(new int[] { p.address, p.address + p.size });
				}
			}
			busy.sort(Comparator.comparingInt((int[] b) -> b[0]));
			int at = z.address;
			for (int[] b : busy) {
				if (b[0] - at >= need) {
					break;
				}
				at = Math.max(at, b[1]);
			}
			if (tailStart[i] - at >= need) {
				ctx.regions.placeFile(f, z.page, at);
				taken.add(new Placed(f, z.page, at, need, z.slice));
				log.info("arena {} : {} -> page {} ${}, in a hole under the zone's tail",
						arena.name, f, z.page, Integer.toHexString(at).toUpperCase());
				return true;
			}
		}
		return false;
	}

	/**
	 * Flow a collection's elements into the zones' free tails, in element
	 * order : one member per tail used, as big as the tail allows, tails
	 * under {@link #GAP_MIN} left empty. Mutates {@code free} — the next
	 * file of the sort sees what the cut consumed. Package-private so the
	 * flow scenarios stay tested without a full build.
	 */
	static void cut(Regions.Region arena, String file, Divisible d, int[] free,
			BuildContext ctx) throws Exception {
		cut(arena, file, d, free, ctx, new ArrayList<Placed>());
	}

	static void cut(Regions.Region arena, String file, Divisible d, int[] free,
			BuildContext ctx, List<Placed> taken) throws Exception {

		int biggest = 0;
		for (int i = 0; i < free.length; i++) {
			biggest = Math.max(biggest, free[i]);
		}

		List<Cuts.Member> members = new ArrayList<Cuts.Member>();
		List<List<Integer>> chunks = new ArrayList<List<Integer>>();
		int zi = 0;
		int used = 0;
		List<Integer> chunk = new ArrayList<Integer>();
		for (int e = 0; e < d.sizes.length; e++) {
			if (d.sizes[e] > biggest) {
				throw new Exception("collection '" + file + "' : '" + d.parts.get(e)[1] + "' is "
						+ d.sizes[e] + " bytes, more than the " + biggest
						+ " bytes of the roomiest free run — an element is never split, it has"
						+ " to be made smaller (or the arena needs a roomier zone)");
			}
			while (zi < free.length
					&& (free[zi] < GAP_MIN || used + d.sizes[e] > free[zi])) {
				if (!chunk.isEmpty()) {
					closeChunk(arena, file, members, chunks, chunk, zi, used, free, ctx, taken);
					chunk = new ArrayList<Integer>();
				}
				zi++;
				used = 0;
			}
			if (zi == free.length) {
				int remaining = 0;
				for (int r = e; r < d.sizes.length; r++) {
					remaining += d.sizes[r];
				}
				throw new Exception("collection '" + file + "' does not fit : " + remaining
						+ " bytes of elements remain and every free run is used — give the"
						+ " arena another <zone>, or put less in the collection");
			}
			chunk.add(e);
			used += d.sizes[e];
		}
		if (!chunk.isEmpty()) {
			closeChunk(arena, file, members, chunks, chunk, zi, used, free, ctx, taken);
		}

		if (members.size() == 1) {
			// one tail held everything : a whole placement wearing a cut's
			// clothes — the file keeps its name and gets a plain placement
			// (reachable in the measured pass only through the blind one,
			// where the whole-fit test did not run)
			ctx.regions.placeFile(file, members.get(0).page, members.get(0).address);
			ctx.cuts.declare(file, new Cuts.Cut(d.parts, chunks, d.gendir, d.units));
		} else {
			ctx.cuts.declare(file, new Cuts.Cut(d.parts, chunks, d.gendir, d.units, members));
		}
		log.info("collection {} : {} member(s) flowed into arena '{}'", file, members.size(),
				arena.name);
	}

	private static void closeChunk(Regions.Region arena, String file,
			List<Cuts.Member> members, List<List<Integer>> chunks, List<Integer> chunk,
			int zi, int used, int[] free, BuildContext ctx, List<Placed> taken) {
		Regions.Zone z = arena.zones.get(zi);
		int at = z.end() - free[zi];
		free[zi] -= used;
		taken.add(new Placed(file, z.page, at, used));
		String memberName = file + "." + members.size();
		members.add(new Cuts.Member(memberName, z.page, at));
		chunks.add(new ArrayList<Integer>(chunk));
		log.debug("arena {} : {} -> page {} ${} ({} elements)", arena.name, memberName,
				z.page, Integer.toHexString(at).toUpperCase(), chunk.size());
	}
}
