package com.widedot.m6809.gamebuilder.plugin.layout;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.config.LayoutResolver;
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
			if ("window".equals(child.getNodeName())) {
				ctx.regions.addWindow(new Regions.Window(
						Attribute.getString(child, ctx, "name"),
						Attribute.getInteger(child, ctx, "address"),
						Attribute.getInteger(child, ctx, "size")));
				continue;
			}
			if ("reserved".equals(child.getNodeName())) {
				ctx.regions.reserve(new Regions.Reserved(
						Attribute.getString(child, ctx, "name"),
						Attribute.getInteger(child, ctx, "page"),
						Attribute.getInteger(child, ctx, "address"),
						Attribute.getInteger(child, ctx, "size")));
				continue;
			}
			if (!"region".equals(child.getNodeName())) {
				throw new Exception(ctx.sources.locate(child) + ": <layout> only contains <window>,"
						+ " <region> and <reserved> elements, found <" + child.getNodeName() + ">");
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
			if (region.pages > 1 && region.stacked) {
				throw new Exception(ctx.sources.locate(node) + ": region '" + region.name
						+ "' cannot be both stacked and multi-page : stacked members are laid out"
						+ " one after the other at run time, which no page boundary survives");
			}
			try {
				ctx.regions.put(region);
			} catch (Exception e) {
				throw new Exception(ctx.sources.locate(node) + ": " + e.getMessage());
			}
			log.debug("region {} : page {}{} address {} size {}{}", region.name, region.page,
					region.pages > 1 ? ".." + (region.page + region.pages - 1) : "",
					region.address, region.size, region.stacked ? " stacked" : "");
		}

		// A region is a promise about where things land ; a reserved range is
		// a promise about where they must not. Both are declarations, so both
		// are checked here — before anything is built, and whatever the size
		// of what ends up being loaded. A region declared over the object pool
		// is a latent fault even while its content stays small.
		java.util.List<String> clashes = new java.util.ArrayList<String>();
		java.util.List<Regions.Region> all = new java.util.ArrayList<Regions.Region>(ctx.regions.all());
		for (int i = 0; i < all.size(); i++) {
			Regions.Region a = all.get(i);
			if (a.size == null) {
				continue;
			}
			for (int j = i + 1; j < all.size(); j++) {
				Regions.Region b = all.get(j);
				if (b.size == null) {
					continue;
				}
				for (int pa = a.page; pa < a.page + a.pages; pa++) {
					for (int pb = b.page; pb < b.page + b.pages; pb++) {
						if (pa == pb && a.address < b.address + b.size
								&& b.address < a.address + a.size) {
							clashes.add(String.format(
									"regions '%s' [$%04X-$%04X] and '%s' [$%04X-$%04X] overlap on page %d",
									a.name, a.address, a.address + a.size - 1,
									b.name, b.address, b.address + b.size - 1, pa));
						}
					}
				}
			}
			for (Regions.Reserved r : ctx.regions.reservedRanges()) {
				for (int pa = a.page; pa < a.page + a.pages; pa++) {
					if (pa == r.page && a.address < r.address + r.size
							&& r.address < a.address + a.size) {
						clashes.add(String.format(
								"region '%s' [$%04X-$%04X] runs into the reserved range '%s'"
								+ " [$%04X-$%04X] on page %d",
								a.name, a.address, a.address + a.size - 1,
								r.name, r.address, r.address + r.size - 1, pa));
					}
				}
			}
		}
		// A region that runs past the end of its window overwrites whatever the
		// machine maps next — invisible until the byte that lands there matters.
		//
		// Only checked when the layout declares its windows (without them the
		// builder has no idea where a page begins or ends) AND when the sizes
		// have been measured : during the discovery pass an auto size takes a
		// whole page, so regions stacked on one page provisionally land at
		// $4000, $8000... The pass exists to measure ; its addresses are not
		// the ones anything is built against.
		if (!ctx.regions.windows().isEmpty() && ctx.regions.hasMeasures()) {
			for (Regions.Region region : ctx.regions.all()) {
				if (region.size == null) {
					continue;
				}
				Regions.Window window = ctx.regions.windowOf(region.address);
				if (window == null) {
					clashes.add(String.format(
							"region '%s' starts at $%04X, which no declared window holds",
							region.name, region.address));
					continue;
				}
				int end = region.address + region.size;
				if (end > window.end()) {
					clashes.add(String.format(
							"region '%s' [$%04X-$%04X] runs %d bytes past the '%s' window"
							+ " [$%04X-$%04X]",
							region.name, region.address, end - 1, end - window.end(),
							window.name, window.address, window.end() - 1));
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
			// include guard : several units of one pageset member may each
			// include this file — a header has to survive double inclusion
			out.append(" IFNDEF LAYOUT_SYMBOLS").append(System.lineSeparator());
			out.append("LAYOUT_SYMBOLS equ 1").append(System.lineSeparator());
			for (Regions.Reserved r : ctx.regions.reservedRanges()) {
				out.append(r.name).append(".address equ $")
				   .append(String.format("%04X", r.address)).append(System.lineSeparator());
				out.append(r.name).append(".size equ ").append(r.size)
				   .append(System.lineSeparator());
			}
			for (Regions.Region region : ctx.regions.all()) {
				out.append(region.name).append(".page equ ").append(region.page)
				   .append(System.lineSeparator());
				out.append(region.name).append(".address equ $")
				   .append(String.format("%04X", region.address)).append(System.lineSeparator());
				if (region.pages > 1) {
					// a multi-page region : the game may need to know how wide
					// its budget is, and its last page
					out.append(region.name).append(".pages equ ").append(region.pages)
					   .append(System.lineSeparator());
					out.append(region.name).append(".page.last equ ")
					   .append(region.page + region.pages - 1).append(System.lineSeparator());
				}
			}
			out.append(" ENDC").append(System.lineSeparator());
			java.nio.file.Files.write(java.nio.file.Paths.get(path),
					out.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));
			log.debug("layout symbols written to {}", gensymbols);
		}

		log.debug("End of processing layout");
	}
}
