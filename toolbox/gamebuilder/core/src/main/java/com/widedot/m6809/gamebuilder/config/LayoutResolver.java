package com.widedot.m6809.gamebuilder.config;

import java.util.LinkedHashMap;
import java.util.Map;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.globals.Regions;

/**
 * Turns a {@code <layout>} declaration into the region map, resolving what the
 * author left to the builder.
 *
 * Destinations were placed entirely by hand, which is honest for a page but
 * hopeless for a size : a region's budget is a number the author has to guess
 * before the content exists, and re-guess every time it changes. Guessing high
 * is the safe move, so every region ends up carrying a tail nobody can use —
 * measured on r-type at 105 060 bytes, six pages, more than the cast that was
 * said not to fit.
 *
 * So a region may say {@code size="auto"} and {@code address="auto"}. The size
 * is what its content measured ; the address is wherever the previous
 * declaration on that page ended. Nothing else changes : the author still
 * chooses the page, which is the decision that carries meaning (what travels
 * together, what a scene swaps).
 *
 * <p><b>Where the measure comes from.</b> The discovery pass the build already
 * runs — to stabilise symbol ids and harvest export offsets — also records what
 * each scene loads where. Its sizes are read back and seeded into the real
 * pass. During discovery itself nothing is measured yet, so an {@code auto}
 * size takes the whole page : the pass exists to measure, its addresses are
 * provisional and its images are thrown away. That is safe precisely because
 * baking is deferred during discovery, so no address is ever resolved against
 * a provisional layout.
 *
 * <p><b>What is not automatic.</b> A {@code <reserved>} range stays explicit :
 * it describes equates that live in the game's source, and the builder cannot
 * measure what it does not produce. And {@code pages="N"} on a multi-page
 * region stays a declared budget — an {@code auto} size there means one whole
 * page, since whole pages are what the budget offers.
 */
public final class LayoutResolver {

	public static final int PAGE_SIZE = 0x4000;

	private LayoutResolver() {
	}

	/**
	 * @param layout the {@code <layout>} node
	 * @return regions in declaration order, every address and size resolved
	 */
	public static Map<String, Regions.Region> resolve(ImmutableNode layout, BuildContext ctx)
			throws Exception {

		// How much physical RAM the report draws : both callers resolve the
		// same layout, so both read it here. 32 pages (512K) unless said.
		Integer ramPages = Attribute.getIntegerOpt(layout, ctx, "pages");
		if (ramPages != null) {
			ctx.regions.setRamPages(ramPages);
		}

		Map<String, Regions.Region> out = new LinkedHashMap<String, Regions.Region>();
		Map<Integer, Integer> cursor = new LinkedHashMap<Integer, Integer>();

		for (ImmutableNode child : layout.getChildren()) {

			if ("reserved".equals(child.getNodeName())) {
				int page = Attribute.getInteger(child, ctx, "page");
				int address = Attribute.getInteger(child, ctx, "address");
				int size = Attribute.getInteger(child, ctx, "size");
				bump(cursor, page, address + size);
				continue;
			}
			boolean isArena = "arena".equals(child.getNodeName());
			if (!isArena && !"region".equals(child.getNodeName())) {
				continue;    // the layout plugin reports what does not belong here
			}

			String name = Attribute.getString(child, ctx, "name");

			if (Attribute.getStringOpt(child, ctx, "stacked") != null) {
				// removed 2026-08 : a run-time-stacked list is what an arena
				// does at build time, better — per-file placement, bakable,
				// and the drift bugs of the loader's walk out of the way
				throw new Exception(ctx.sources.locate(child) + ": region '" + name
						+ "' declares stacked=… — this attribute no longer exists. Declare an"
						+ " <arena name=\"" + name + "\"> with one <zone> per page of room, and"
						+ " load into it with <load arena=\"" + name + "\"> : the builder lays"
						+ " the files out itself and publishes <file>.page / <file>.address");
			}

			// Zones declared as children : the region says WHERE it lives, in
			// as many pieces as it needs. The compact form — page, address and
			// size on the element — is read further down and becomes a single
			// zone, so the rest of the builder sees one shape only.
			java.util.List<Regions.Zone> zones = new java.util.ArrayList<Regions.Zone>();
			if (isArena && child.getChildren().isEmpty()) {
				throw new Exception(ctx.sources.locate(child) + ": arena '" + name
						+ "' declares no <zone> — an arena IS its list of places");
			}
			for (ImmutableNode z : child.getChildren()) {
				if (!"zone".equals(z.getNodeName())) {
					throw new Exception(ctx.sources.locate(z) + ": <" + z.getNodeName()
							+ "> is not valid inside a <region> ; only <zone> is");
				}
				zones.add(new Regions.Zone(
						Attribute.getInteger(z, ctx, "page"),
						Attribute.getInteger(z, ctx, "address"),
						Attribute.getInteger(z, ctx, "size")));
			}
			if (!zones.isEmpty()) {
				// the first zone stands for the region wherever the builder
				// still expects a single destination ; nothing reads the rest
				// yet, that is the next step
				Regions.Zone head = zones.get(0);
				for (Regions.Zone z : zones) {
					bump(cursor, z.page, z.end());
				}
				// pages still counts the zones : the rest of the builder reads
				// it to walk a region's pages, and a zone is one page's worth
				out.put(name, new Regions.Region(name, head.page, head.address, head.size,
						zones.size(), zones, isArena));
				continue;
			}
			// The layout declares CONSTRAINTS, not decisions : what the author
			// does not write, the builder works out. An attribute that is
			// absent means "up to you" ; "auto" is still accepted, and says
			// the same thing out loud.
			int page = Attribute.getInteger(child, ctx, "page");
			int pages = Attribute.getInteger(child, ctx, "pages", 1);
			String rawSize = Attribute.getStringOpt(child, ctx, "size");
			String rawAddress = Attribute.getStringOpt(child, ctx, "address");
			boolean autoSize = rawSize == null || "auto".equals(rawSize);
			boolean autoAddress = rawAddress == null || "auto".equals(rawAddress);

			// First region of a page : nothing says where the page begins —
			// that belongs to the machine, not to the layout. The one who
			// opens a page states the address ; whoever follows may leave it.
			if (autoAddress && !cursor.containsKey(page)) {
				throw new Exception(ctx.sources.locate(child) + ": region '" + name
						+ "' leaves its address to the builder but nothing precedes it on"
						+ " page " + page + " — a page does not say where it begins, so the"
						+ " first region of a page states its address");
			}
			int address = autoAddress ? at(cursor, page)
					: Attribute.getInteger(child, ctx, "address");

			Integer size;
			if (!autoSize) {
				// a declared size is a BUDGET : the build refuses content that
				// outgrows it, which is the whole point of writing it down
				size = Attribute.getIntegerOpt(child, ctx, "size");
			} else if (pages > 1) {
				// a multi-page budget offers whole pages ; each zone's capacity is the page
				size = PAGE_SIZE;
			} else {
				Integer m = ctx.regions.measured(name);
				// no measure yet : the discovery pass is running, and it is the
				// one that will produce it. Take the page so nothing it builds
				// is refused for a budget that does not exist yet.
				size = m != null ? m : PAGE_SIZE;
			}

			if (autoAddress && size == null) {
				throw new Exception(ctx.sources.locate(child) + ": region '" + name
						+ "' has address=\"auto\" but no size — the builder can only place it"
						+ " after what precedes it if it knows how much room that took");
			}
			// No page-bound check here : a layout never declares where a page
			// begins or ends, and the bounds differ with the window the page is
			// seen through — the resident RAM opens at $6100, the cartridge
			// window at $0000. The overlap checks the layout plugin runs are
			// what catches a region placed on top of something.

			out.put(name, new Regions.Region(name, page, address, size, pages));

			if (pages > 1) {
				for (int p = 0; p < pages; p++) {
					bump(cursor, page + p, PAGE_SIZE);
				}
			} else if (size != null) {
				bump(cursor, page, address + size);
			}
		}
		return out;
	}

	private static int at(Map<Integer, Integer> cursor, int page) {
		Integer c = cursor.get(page);
		return c == null ? 0 : c;
	}

	private static void bump(Map<Integer, Integer> cursor, int page, int end) {
		if (end > at(cursor, page)) {
			cursor.put(page, end);
		}
	}
}
