package com.widedot.m6809.gamebuilder.config;

import java.util.LinkedHashMap;
import java.util.Map;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Values;
import com.widedot.m6809.gamebuilder.spi.globals.Regions;

import lombok.extern.slf4j.Slf4j;

/**
 * Collects, before a target runs, where its scenes load each file — the
 * placement half of what static resolution needs (see StaticLink).
 *
 * This walks the raw tree rather than waiting for the scene plugins to run,
 * because link data is emitted as each file is built and the scenes are
 * declared after them. Placements are pure configuration — a region name from
 * the layout, or a literal destination on the load — so nothing here needs
 * the build to have started.
 *
 * An arena-bound load is placed where the packing put it — the builder decides
 * the address, then stands by its decision everywhere, including here.
 */
@Slf4j
public final class PlacementScan {

	private PlacementScan() {
	}

	public static void run(ImmutableNode targetNode, BuildContext ctx) throws Exception {
		// regions first : loads reference them by name
		Map<String, Regions.Region> resolved = new LinkedHashMap<String, Regions.Region>();
		Map<String, int[]> regions = new LinkedHashMap<String, int[]>();     // name -> page, address
		collectRegions(targetNode, ctx, regions, resolved);
		// arenas next : where an arena-bound file lands depends on all the
		// files bound to that arena, so it cannot be decided region by region
		ctx.regions.clearFilePlacements();
		ArenaPacker.pack(targetNode, ctx, resolved);
		collectLoads(targetNode, ctx, regions);
	}

	private static void collectRegions(ImmutableNode node, BuildContext ctx,
			Map<String, int[]> regions,
			Map<String, Regions.Region> resolved) throws Exception {
		if ("layout".equals(node.getNodeName())) {
			// the same resolver the layout plugin uses, so an auto address or
			// size is seen identically here — a placement scan that disagreed
			// with the layout would bake references against addresses nothing
			// ever loads at
			for (com.widedot.m6809.gamebuilder.spi.globals.Regions.Region r
					: LayoutResolver.resolve(node, ctx).values()) {
				resolved.put(r.name, r);
				regions.put(r.name, new int[] { r.page, r.address });
				if (Boolean.parseBoolean(raw(findRegion(node, r.name), "interface"))) {
					ctx.staticLink.declareInterfaceRegion(r.name, r.page, r.address);
				}
			}
		}
		for (ImmutableNode child : node.getChildren()) {
			collectRegions(child, ctx, regions, resolved);
		}
	}

	/** the declaration a resolved region came from, for its remaining attributes */
	private static ImmutableNode findRegion(ImmutableNode layout, String name) {
		for (ImmutableNode child : layout.getChildren()) {
			if ("region".equals(child.getNodeName()) && name.equals(raw(child, "name"))) {
				return child;
			}
		}
		return null;
	}

	private static void collectLoads(ImmutableNode node, BuildContext ctx,
			Map<String, int[]> regions) {
		if ("scene".equals(node.getNodeName())) {
			String scene = raw(node, "name");
			for (ImmutableNode load : node.getChildren()) {
				if (!"load".equals(load.getNodeName())) {
					continue;
				}
				String name = raw(load, "name");
				if (name == null) {
					continue; // the scene plugin reports malformed loads itself
				}
				String arenaName = raw(load, "arena");
				if (arenaName != null) {
					int[] at = ctx.regions.filePlacement(name);
					if (at != null) {
						ctx.staticLink.place(name, at[0], at[1], scene);
					}
					continue;
				}
				String regionName = raw(load, "region");
				if (regionName != null) {
					int[] destination = regions.get(regionName);
					if (destination == null) {
						continue; // unknown region : the scene plugin reports it
					}
					ctx.staticLink.place(name, destination[0], destination[1], scene);
					continue;
				}
				Integer page = number(load, "page");
				Integer address = number(load, "address");
				if (page != null && address != null) {
					// a literal destination is placed all the same
					ctx.staticLink.place(name, page, address, scene);
				}
			}
		}
		for (ImmutableNode child : node.getChildren()) {
			collectLoads(child, ctx, regions);
		}
	}

	private static String raw(ImmutableNode node, String attribute) {
		if (node == null) {
			return null;
		}
		Object value = node.getAttributes().get(attribute);
		return value == null ? null : value.toString();
	}

	private static Integer number(ImmutableNode node, String attribute) {
		String value = raw(node, attribute);
		if (value == null) {
			return null;
		}
		try {
			return Values.parseInt(value);
		} catch (Exception e) {
			return null; // malformed values are the owning plugin's to report
		}
	}
}
