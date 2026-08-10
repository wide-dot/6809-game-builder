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
		// attributed places next : a bare load resolves against what its file
		// declared, so the map must exist before loads and arenas are read
		ctx.filePlaces.clear();
		collectFilePlaces(targetNode, ctx);
		// arenas next : where an arena-bound file lands depends on all the
		// files bound to that arena, so it cannot be decided region by region
		ctx.regions.clearFilePlacements();
		ArenaPacker.pack(targetNode, ctx, resolved);
		collectLoads(targetNode, ctx, regions);
	}

	/**
	 * Collects the destinations declared on the file declarations themselves :
	 * {@code arena=}, {@code region=} or {@code page=}+{@code address=} on a
	 * {@code <file>}, and the {@code region=} a {@code <pageset>} already
	 * carries. Read literally, like every attribute of this scan — the place
	 * is configuration, not something a default cascade should move.
	 */
	private static void collectFilePlaces(ImmutableNode node, BuildContext ctx) throws Exception {
		String kind = node.getNodeName();
		if ("file".equals(kind)) {
			String name = raw(node, "name");
			String arena = raw(node, "arena");
			String region = raw(node, "region");
			Integer page = number(node, "page");
			Integer address = number(node, "address");
			if (name != null && (arena != null || region != null || page != null || address != null)) {
				String where = ctx.sources.locate(node);
				int forms = (arena != null ? 1 : 0) + (region != null ? 1 : 0)
						+ (page != null || address != null ? 1 : 0);
				if (forms > 1) {
					throw new Exception(where + ": file '" + name + "' declares more than one"
							+ " attributed place — give one of arena, region, or page+address");
				}
				if ((page == null) != (address == null)) {
					throw new Exception(where + ": file '" + name + "' needs both page and"
							+ " address for a raw attributed place");
				}
				ctx.filePlaces.declare(name, new com.widedot.m6809.gamebuilder.spi.globals
						.FilePlaces.Place(arena, region, page, address, where));
			}
		} else if ("pageset".equals(kind)) {
			// a pageset's region IS its attributed place, declared since the
			// multi-page work : record it so a scene can name the set bare
			String name = raw(node, "name");
			String region = raw(node, "region");
			if (name != null && region != null) {
				ctx.filePlaces.declare(name, new com.widedot.m6809.gamebuilder.spi.globals
						.FilePlaces.Place(null, region, null, null, ctx.sources.locate(node)));
			}
		}
		for (ImmutableNode child : node.getChildren()) {
			collectFilePlaces(child, ctx);
		}
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
				String regionName = raw(load, "region");
				Integer page = number(load, "page");
				Integer address = number(load, "address");
				if (arenaName == null && regionName == null && page == null
						&& address == null) {
					// a bare load : the file's attributed place, when it has one
					com.widedot.m6809.gamebuilder.spi.globals.FilePlaces.Place attributed =
							ctx.filePlaces.get(name);
					if (attributed != null) {
						arenaName = attributed.arena;
						regionName = attributed.region;
						page = attributed.page;
						address = attributed.address;
					}
				}
				if (arenaName != null) {
					int[] at = ctx.regions.filePlacement(name);
					if (at != null) {
						ctx.staticLink.place(name, at[0], at[1], scene);
					}
					continue;
				}
				if (regionName != null) {
					int[] destination = regions.get(regionName);
					if (destination == null) {
						continue; // unknown region : the scene plugin reports it
					}
					ctx.staticLink.place(name, destination[0], destination[1], scene);
					continue;
				}
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
