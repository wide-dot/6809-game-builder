package com.widedot.m6809.gamebuilder.plugin.layout;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.config.CompositionScan;
import com.widedot.m6809.gamebuilder.config.LayoutResolver;
import com.widedot.m6809.gamebuilder.spi.globals.Compositions;
import com.widedot.m6809.gamebuilder.spi.globals.Regions;

import lombok.extern.slf4j.Slf4j;

/**
 * Declares the memory layout of a target : named regions at fixed
 * destinations, that scene loads reference instead of raw page/address pairs.
 */
@Slf4j
public class LayoutPlugin {

	public static void run(ImmutableNode node, BuildContext ctx) throws Exception {

		log.debug("Processing layout ...");

		String gensymbols = Attribute.getStringOpt(node, ctx, "gensymbols");

		// The reserved ranges stay as declared : they describe equates that
		// live in the game's source, and the builder cannot measure what it
		// does not produce.
		for (ImmutableNode child : node.getChildren()) {
			if ("reserved".equals(child.getNodeName())) {
				ctx.regions.reserve(new Regions.Reserved(
						Attribute.getString(child, ctx, "name"),
						Attribute.getInteger(child, ctx, "page"),
						Attribute.getInteger(child, ctx, "address"),
						Attribute.getInteger(child, ctx, "size"),
						Attribute.getIntegerOpt(child, ctx, "slice")));
				continue;
			}
			// A composition names the scenes that are resident TOGETHER. It is
			// declared here, beside the regions and the arenas, because it
			// describes memory and not content ; the scenes it names are
			// declared further down in the media, so they are forward
			// references — resolved by the check at the end of the target.
			// The reading itself lives in CompositionScan : the placement scan
			// does it too, before anything assembles, to write the tables.
			if ("composition".equals(child.getNodeName())) {
				continue;
			}
			if (!"region".equals(child.getNodeName()) && !"arena".equals(child.getNodeName())) {
				throw new Exception(ctx.sources.locate(child) + ": <layout> only contains"
						+ " <region>, <arena>, <composition> and <reserved> elements, found <"
						+ child.getNodeName() + ">");
			}
		}

		for (Compositions.Composition c : CompositionScan.parse(node, ctx)) {
			try {
				ctx.compositions.declare(c);
			} catch (Exception e) {
				throw new Exception(c.where + ": " + e.getMessage());
			}
		}

		// Addresses and sizes may be left to the builder (size="auto",
		// address="auto") : the resolver reads back what the discovery pass
		// measured and stacks what follows. Same call as PlacementScan makes,
		// so both see the identical layout.
		for (Regions.Region region : LayoutResolver.resolve(node, ctx).values()) {
			if (region.pages < 1) {
				throw new Exception(ctx.sources.locate(node) + ": region '" + region.name
						+ "' spans " + region.pages + " pages, which cannot be");
			}
			try {
				ctx.regions.put(region);
			} catch (Exception e) {
				throw new Exception(ctx.sources.locate(node) + ": " + e.getMessage());
			}
			log.debug("region {} : page {}{} address {} size {}{}", region.name, region.page,
					region.pages > 1 ? ".." + (region.page + region.pages - 1) : "",
					region.address, region.size, region.packed ? " arena" : "");
		}

		// A region is a promise about where things land ; a reserved range is
		// a promise about where they must not. Only the second is checked
		// here, and it is checked whatever the sizes : the object pool, the
		// stack and the video buffers do not negotiate.
		//
		// Two CONTAINERS overlapping is no longer an error. The builder does
		// not know the order of the game's screens — that belongs to the game
		// code — so it cannot tell a title screen legitimately reusing a
		// family's RAM from a mistake. What it can tell, and does, is that no
		// single SCENE writes twice to the same bytes (SceneChecks). The rest
		// is shown, not refused : see the occupancy report.
		java.util.List<String> clashes = new java.util.ArrayList<String>();
		com.widedot.m6809.gamebuilder.spi.globals.Machines.Machine machine = ctx.machines.current();
		com.widedot.m6809.gamebuilder.spi.globals.WindowMap windows =
				machine == null || machine.windows.isEmpty() ? null : machine.windows();
		if (ctx.regions.hasMeasures() && windows != null) {
			// Compared in the ABSOLUTE referential : a zone and a reserved
			// range may be reached through two different windows and still be
			// the same silicon — page 1 seen from the resident window is the
			// page 1 a cartridge mount would show.
			for (Regions.Region a : ctx.regions.all()) {
				for (Regions.Zone z : a.zones) {
					java.util.List<int[]> zone = windows.footprint(
							Integer.valueOf(z.page), z.address, z.size, null);
					for (Regions.Reserved r : ctx.regions.reservedRanges()) {
						java.util.List<int[]> range = windows.footprint(
								Integer.valueOf(r.page), r.address, r.size, r.slice);
						if (com.widedot.m6809.gamebuilder.spi.globals.WindowMap
								.overlap(zone, range)) {
							clashes.add(String.format(
									"region '%s' [$%04X-$%04X] runs into the reserved range '%s'"
									+ " [$%04X-$%04X] — both are %s",
									a.name, z.address, z.end() - 1,
									r.name, r.address, r.address + r.size - 1,
									windows.describe(range)));
						}
					}
				}
			}
		}

		if (!clashes.isEmpty()) {
			throw new Exception(ctx.sources.locate(node) + ": the memory layout overlaps itself:"
					+ System.lineSeparator() + "  " + String.join(System.lineSeparator() + "  ", clashes));
		}

		// export the layout as equates : the game code includes this file
		// instead of duplicating pages and addresses by hand ("as defined in
		// scene file" comments are exactly the smell this removes)
		if (gensymbols != null) {
			String path = ctx.path + java.io.File.separator + gensymbols;
			java.nio.file.Files.createDirectories(
					java.nio.file.Paths.get(com.widedot.m6809.util.FileUtil.getDir(path)));
			StringBuilder out = new StringBuilder();
			// include guard : several units of one member may each include
			// this file — a header has to survive double inclusion
			out.append(" IFNDEF LAYOUT_SYMBOLS").append(System.lineSeparator());
			out.append("LAYOUT_SYMBOLS equ 1").append(System.lineSeparator());
			// one name publishes page and address, nothing else : .size,
			// .pages and .page.last were emitted too and measured at zero
			// consumers over the whole corpus (phase 9 sweep, 2026-08-13) —
			// re-add one the day a game reads it, not before
			for (Regions.Reserved r : ctx.regions.reservedRanges()) {
				out.append(r.name).append(".address equ $")
				   .append(String.format("%04X", r.address)).append(System.lineSeparator());
			}
			for (Regions.Region region : ctx.regions.all()) {
				out.append(region.name).append(".page equ ").append(region.page)
				   .append(System.lineSeparator());
				out.append(region.name).append(".address equ $")
				   .append(String.format("%04X", region.address)).append(System.lineSeparator());
			}
			// What the packer decided, published per FILE : an arena holds
			// several of them, so <region>.page would name nothing. This is
			// what an object index reads to mount the page before jumping.
			for (java.util.Map.Entry<String, int[]> e : ctx.regions.filePlacements().entrySet()) {
				out.append(e.getKey()).append(".page equ ").append(e.getValue()[0])
				   .append(System.lineSeparator());
				out.append(e.getKey()).append(".address equ $")
				   .append(String.format("%04X", e.getValue()[1])).append(System.lineSeparator());
			}
			out.append(" ENDC").append(System.lineSeparator());
			java.nio.file.Files.write(java.nio.file.Paths.get(path),
					out.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));
			log.debug("layout symbols written to {}", gensymbols);
		}

		log.debug("End of processing layout");
	}
}
