package com.widedot.m6809.gamebuilder.config;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
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
 * arenas declaring the same zones : the layout allows contenders to overlap,
 * and the per-scene check is what verifies they never coexist.
 *
 * <p><b>Largest first.</b> Small files then fill what the big ones leave, which
 * is the difference between reaching the theoretical page count and wasting one
 * page in three (measured on r-type : 8 pages against 12 for the same content).
 * Ties keep declaration order, so a build stays reproducible.
 */
@Slf4j
public final class ArenaPacker {

	private ArenaPacker() {
	}

	/**
	 * Decide where every arena-bound file lands, and record it in the context.
	 * Idempotent : both the placement scan and the scene plugin resolve the
	 * same target and must see the same answer.
	 *
	 * @param target the target node, walked for its scene loads
	 * @param regions the resolved layout
	 */
	public static void pack(ImmutableNode target, BuildContext ctx,
			Map<String, Regions.Region> regions) throws Exception {

		// file order per arena, as the scenes declare them
		Map<String, List<String>> wanted = new LinkedHashMap<String, List<String>>();
		collect(target, ctx, wanted);
		if (wanted.isEmpty()) {
			return;
		}

		for (Map.Entry<String, List<String>> e : wanted.entrySet()) {
			Regions.Region arena = regions.get(e.getKey());
			if (arena == null) {
				throw new Exception("unknown arena '" + e.getKey() + "' (layout declares: "
						+ regions.keySet() + ")");
			}
			place(arena, e.getValue(), ctx);
		}
	}

	private static void collect(ImmutableNode node, BuildContext ctx,
			Map<String, List<String>> wanted) throws Exception {
		if ("load".equals(node.getNodeName())) {
			String arena = Attribute.getStringOpt(node, ctx, "arena");
			if (arena != null) {
				List<String> files = wanted.computeIfAbsent(arena, k -> new ArrayList<String>());
				String name = Attribute.getString(node, ctx, "name");
				if (!files.contains(name)) {
					files.add(name);    // a file loaded by two scenes is placed once
				}
			}
		}
		for (ImmutableNode child : node.getChildren()) {
			collect(child, ctx, wanted);
		}
	}

	private static void place(Regions.Region arena, List<String> files, BuildContext ctx)
			throws Exception {

		// how much room each zone has left, in declaration order
		int[] free = new int[arena.zones.size()];
		for (int i = 0; i < free.length; i++) {
			free[i] = arena.zones.get(i).size;
		}

		List<String> order = new ArrayList<String>(files);
		final Map<String, Integer> sizes = new LinkedHashMap<String, Integer>();
		boolean measured = true;
		for (String f : files) {
			Integer s = ctx.regions.fileSize(f);
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
			// anything to be measured at all.
			Regions.Zone head = arena.zones.get(0);
			int at = head.address;
			for (String f : files) {
				ctx.regions.placeFile(f, head.page, at);
				Integer known = ctx.regions.fileSize(f);
				at += known == null ? 1 : known;
			}
			return;
		}

		// largest first ; ties keep the order the scenes declared them in
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
			if (chosen < 0) {
				int biggest = 0;
				for (int r : free) {
					biggest = Math.max(biggest, r);
				}
				throw new Exception("arena '" + arena.name + "' cannot hold '" + f + "' : it needs "
						+ need + " bytes in one run, the roomiest zone has " + biggest
						+ " left — give the arena another <zone>, or make the file smaller");
			}
			Regions.Zone z = arena.zones.get(chosen);
			int at = z.end() - free[chosen];
			free[chosen] -= need;
			ctx.regions.placeFile(f, z.page, at);
			log.debug("arena {} : {} -> page {} ${}", arena.name, f, z.page,
					Integer.toHexString(at).toUpperCase());
		}
	}
}
