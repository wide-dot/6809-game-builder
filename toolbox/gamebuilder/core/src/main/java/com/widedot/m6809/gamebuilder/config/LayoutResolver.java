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
 * page, since a pageset's per-page capacity is what it asks for.
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

		Map<String, Regions.Region> out = new LinkedHashMap<String, Regions.Region>();
		Map<Integer, Integer> cursor = new LinkedHashMap<Integer, Integer>();
		// Every page some declaration starts on. A pages="auto" region with no
		// measure yet claims room up to the next one : generous enough that the
		// discovery pack never hits a ceiling, bounded so two of them never
		// overlap. The measure replaces it in the real pass.
		java.util.TreeSet<Integer> claimed = new java.util.TreeSet<Integer>();
		for (ImmutableNode c : layout.getChildren()) {
			if ("region".equals(c.getNodeName()) || "reserved".equals(c.getNodeName())) {
				claimed.add(Attribute.getInteger(c, ctx, "page"));
			}
		}

		for (ImmutableNode child : layout.getChildren()) {

			if ("reserved".equals(child.getNodeName())) {
				int page = Attribute.getInteger(child, ctx, "page");
				int address = Attribute.getInteger(child, ctx, "address");
				int size = Attribute.getInteger(child, ctx, "size");
				bump(cursor, page, address + size);
				continue;
			}
			if (!"region".equals(child.getNodeName())) {
				continue;    // the layout plugin reports what does not belong here
			}

			String name = Attribute.getString(child, ctx, "name");
			int page = Attribute.getInteger(child, ctx, "page");

			String rawPages = Attribute.getStringOpt(child, ctx, "pages");
			int pages;
			if (!"auto".equals(rawPages)) {
				pages = Attribute.getInteger(child, ctx, "pages", 1);
			} else {
				Integer m = ctx.regions.measuredPages(name);
				if (m != null) {
					pages = m;
				} else {
					Integer next = claimed.higher(page);
					pages = next != null ? next - page : 1;
				}
			}
			boolean stacked = Attribute.getBoolean(child, ctx, "stacked", false);

			String rawSize = Attribute.getStringOpt(child, ctx, "size");
			String rawAddress = Attribute.getStringOpt(child, ctx, "address");
			boolean autoSize = "auto".equals(rawSize);
			boolean autoAddress = "auto".equals(rawAddress);

			if (autoAddress && !cursor.containsKey(page)) {
				throw new Exception(ctx.sources.locate(child) + ": region '" + name
						+ "' has address=\"auto\" but nothing precedes it on page " + page
						+ " — a page does not say where it begins (the resident window opens"
						+ " at $6100, the cartridge one at $0000), so the first declaration"
						+ " on a page gives its address");
			}
			int address = autoAddress ? at(cursor, page)
					: Attribute.getInteger(child, ctx, "address");

			Integer size;
			if (!autoSize) {
				size = Attribute.getIntegerOpt(child, ctx, "size");
			} else if (pages > 1) {
				// a pageset asks for whole pages ; its per-page capacity is the page
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

			out.put(name, new Regions.Region(name, page, address, size, stacked, pages));

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
