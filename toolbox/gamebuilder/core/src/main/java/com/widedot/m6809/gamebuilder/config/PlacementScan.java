package com.widedot.m6809.gamebuilder.config;

import java.util.LinkedHashMap;
import java.util.Map;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Values;

import lombok.extern.slf4j.Slf4j;

/**
 * Collects, before a target runs, where its scenes load each direntry — the
 * placement half of what static resolution needs (see StaticLink).
 *
 * This walks the raw tree rather than waiting for the scene plugins to run,
 * because link data is emitted as each direntry is built and the scenes are
 * declared after them. Placements are pure configuration — a region name from
 * the layout, or a literal destination on the load — so nothing here needs
 * the build to have started.
 *
 * A load into a bulk region is recorded as unusable for static resolution :
 * bulk members are laid out one after the other at run time, so no member has
 * a declared address of its own.
 */
@Slf4j
public final class PlacementScan {

	private PlacementScan() {
	}

	public static void run(ImmutableNode targetNode, BuildContext ctx) throws Exception {
		// regions first : loads reference them by name
		Map<String, int[]> regions = new LinkedHashMap<String, int[]>();     // name -> page, address
		Map<String, Boolean> bulks = new LinkedHashMap<String, Boolean>();
		collectRegions(targetNode, ctx, regions, bulks);
		collectLoads(targetNode, ctx, regions, bulks);
	}

	private static void collectRegions(ImmutableNode node, BuildContext ctx,
			Map<String, int[]> regions, Map<String, Boolean> bulks) throws Exception {
		if ("layout".equals(node.getNodeName())) {
			for (ImmutableNode region : node.getChildren()) {
				if (!"region".equals(region.getNodeName())) {
					continue;
				}
				String name = raw(region, "name");
				Integer page = number(region, "page");
				Integer address = number(region, "address");
				if (name == null || page == null || address == null) {
					continue; // the layout plugin reports malformed regions itself
				}
				regions.put(name, new int[] { page, address });
				bulks.put(name, Boolean.parseBoolean(raw(region, "bulk")));
				if (Boolean.parseBoolean(raw(region, "interface"))) {
					// an interface region promises its alternatives the same
					// run-time face ; bulk members have no destination of
					// their own so the promise cannot even be stated
					if (Boolean.TRUE.equals(bulks.get(name))) {
						throw new Exception("region '" + name
								+ "' cannot be both bulk and interface");
					}
					ctx.staticLink.declareInterfaceRegion(name, page, address);
				}
			}
		}
		for (ImmutableNode child : node.getChildren()) {
			collectRegions(child, ctx, regions, bulks);
		}
	}

	private static void collectLoads(ImmutableNode node, BuildContext ctx,
			Map<String, int[]> regions, Map<String, Boolean> bulks) {
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
					if (Boolean.TRUE.equals(bulks.get(regionName))) {
						ctx.staticLink.placeConflict(name, "scene " + scene + " loads it into the"
								+ " bulk region '" + regionName + "', whose members have no"
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
			collectLoads(child, ctx, regions, bulks);
		}
	}

	private static String raw(ImmutableNode node, String attribute) {
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
