package com.widedot.m6809.gamebuilder.config;

import java.util.LinkedHashMap;
import java.util.Map;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Values;

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
 * A load into a stacked region is recorded as unusable for static resolution :
 * stacked members are laid out one after the other at run time, so no member has
 * a declared address of its own.
 */
@Slf4j
public final class PlacementScan {

	private PlacementScan() {
	}

	public static void run(ImmutableNode targetNode, BuildContext ctx) throws Exception {
		// regions first : loads reference them by name
		Map<String, int[]> regions = new LinkedHashMap<String, int[]>();     // name -> page, address
		Map<String, Boolean> stackeds = new LinkedHashMap<String, Boolean>();
		collectRegions(targetNode, ctx, regions, stackeds);
		collectLoads(targetNode, ctx, regions, stackeds);
	}

	private static void collectRegions(ImmutableNode node, BuildContext ctx,
			Map<String, int[]> regions, Map<String, Boolean> stackeds) throws Exception {
		if ("layout".equals(node.getNodeName())) {
			// the same resolver the layout plugin uses, so an auto address or
			// size is seen identically here — a placement scan that disagreed
			// with the layout would bake references against addresses nothing
			// ever loads at
			for (com.widedot.m6809.gamebuilder.spi.globals.Regions.Region r
					: LayoutResolver.resolve(node, ctx).values()) {
				regions.put(r.name, new int[] { r.page, r.address });
				stackeds.put(r.name, r.stacked);
				if (Boolean.parseBoolean(raw(findRegion(node, r.name), "interface"))) {
					if (r.stacked) {
						throw new Exception("region '" + r.name
								+ "' cannot be both stacked and interface");
					}
					ctx.staticLink.declareInterfaceRegion(r.name, r.page, r.address);
				}
			}
		}
		for (ImmutableNode child : node.getChildren()) {
			collectRegions(child, ctx, regions, stackeds);
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
			Map<String, int[]> regions, Map<String, Boolean> stackeds) {
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
				String regionName = raw(load, "region");
				if (regionName != null) {
					if (Boolean.TRUE.equals(stackeds.get(regionName))) {
						ctx.staticLink.placeConflict(name, "scene " + scene + " loads it into the"
								+ " stacked region '" + regionName + "', whose members have no"
								+ " declared address of their own");
						continue;
					}
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
			collectLoads(child, ctx, regions, stackeds);
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
