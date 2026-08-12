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
		java.util.Set<String> pagesets = new java.util.LinkedHashSet<String>();
		collectFilePlaces(targetNode, ctx, pagesets);
		// collections next : a file whose top-level children can all name
		// their parts is an element list to the placement. Its elements are
		// measured HERE, before the sort — with the defaults its directory
		// declares, replayed exactly as the reservation will replay them
		// (lwasm.format=obj is what the measure assembly needs)
		ctx.cuts.clear();
		java.util.Map<String, ArenaPacker.Divisible> divisibles =
				new java.util.LinkedHashMap<String, ArenaPacker.Divisible>();
		collectDivisibles(targetNode, ctx, divisibles);
		// arenas last : where an arena-bound file lands depends on all the
		// files bound to that arena, so it cannot be decided region by region.
		// One sort, whole if it fits, cut if it cannot (5c).
		ctx.regions.clearFilePlacements();
		ArenaPacker.pack(targetNode, ctx, resolved, pagesets, divisibles);
		collectLoads(targetNode, ctx, regions);
	}

	/**
	 * Finds and measures the collections : arena-bound files whose top-level
	 * children can ALL name their parts (the plugin is the frontier — lwasm
	 * yields one element, gfxcomp exposes N). The walk replays each
	 * container's <default>/<define> into a scratch context so the measure
	 * assembles under the same configuration the emission will see.
	 */
	private static void collectDivisibles(ImmutableNode node, BuildContext ctx,
			java.util.Map<String, ArenaPacker.Divisible> divisibles) throws Exception {
		BuildContext scope = ctx.child();
		for (ImmutableNode child : node.getChildren()) {
			String kind = child.getNodeName();
			if ("default".equals(kind) || "define".equals(kind)) {
				com.widedot.m6809.gamebuilder.Handlers.getDefault(kind).run(child, scope);
				continue;
			}
			if ("file".equals(kind)) {
				String name = raw(child, "name");
				com.widedot.m6809.gamebuilder.spi.globals.FilePlaces.Place place =
						name == null ? null : scope.filePlaces.get(name);
				if (place == null || place.arena == null) {
					continue;
				}
				java.util.List<String[]> parts = null;
				boolean allParts = false;
				for (ImmutableNode content : child.getChildren()) {
					com.widedot.m6809.gamebuilder.spi.PartsPluginInterface handler =
							com.widedot.m6809.gamebuilder.Handlers.getParts(content.getNodeName());
					if (handler == null) {
						allParts = false;
						break;
					}
					// generated part symbols are qualified by the FILE : the
					// member split is the packing's result, and a symbol name
					// must not change when the packing does
					scope.staticLink.setCurrentHost(name);
					if (parts == null) {
						parts = new java.util.ArrayList<String[]>();
					}
					parts.addAll(handler.getParts(content, scope));
					allParts = true;
				}
				if (!allParts || parts == null || parts.isEmpty()) {
					continue;
				}
				String gendir = raw(child, "gendir");
				if (gendir == null) {
					throw new Exception(scope.sources.locate(child) + ": collection '" + name
							+ "' needs gendir= : its member sources are generated");
				}
				int[] sizes = com.widedot.m6809.gamebuilder.plugin.collection.CollectionPlugin
						.measure(name, parts, scope, gendir);
				divisibles.put(name, new ArenaPacker.Divisible(parts, sizes, gendir));
				continue;
			}
			// recurse with the SCOPE : a directory's defaults stack on its
			// floppydisk's, exactly as the real walk nests its contexts
			collectDivisibles(child, scope, divisibles);
		}
	}

	/**
	 * Collects the destinations declared on the file declarations themselves :
	 * {@code arena=}, {@code region=} or {@code page=}+{@code address=} on a
	 * {@code <file>}, and the {@code region=} a {@code <pageset>} already
	 * carries. Read literally, like every attribute of this scan — the place
	 * is configuration, not something a default cascade should move.
	 */
	private static void collectFilePlaces(ImmutableNode node, BuildContext ctx,
			java.util.Set<String> pagesets) throws Exception {
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
			// a pageset's region — or arena, for the gap-flowing form — IS its
			// attributed place, declared since the multi-page work : record it
			// so a scene can name the set bare
			String name = raw(node, "name");
			String region = raw(node, "region");
			String arena = raw(node, "arena");
			if (name != null && (region != null || arena != null)) {
				ctx.filePlaces.declare(name, new com.widedot.m6809.gamebuilder.spi.globals
						.FilePlaces.Place(arena, region, null, null, ctx.sources.locate(node)));
			}
			if (name != null) {
				pagesets.add(name);
			}
		}
		for (ImmutableNode child : node.getChildren()) {
			collectFilePlaces(child, ctx, pagesets);
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
			}
		}
		for (ImmutableNode child : node.getChildren()) {
			collectRegions(child, ctx, regions, resolved);
		}
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
