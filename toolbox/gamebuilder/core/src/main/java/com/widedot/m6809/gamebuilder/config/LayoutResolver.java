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

		// The windows come first, and the RESOLVER reads them — not its
		// caller. Both the placement scan and the layout plugin resolve the
		// same layout, and the scan runs before the plugin has parsed
		// anything : a resolver that depended on its caller having declared
		// the windows would place a region at $0000 for one and at $2E68 for
		// the other. The bake follows the scan, the loader follows the
		// plugin, and the game jumps into empty RAM. Idempotent on purpose —
		// both callers pay the same two lines.
		ctx.regions.clearWindows();
		for (ImmutableNode c : layout.getChildren()) {
			if ("window".equals(c.getNodeName())) {
				ctx.regions.addWindow(new Regions.Window(
						Attribute.getString(c, ctx, "name"),
						Attribute.getInteger(c, ctx, "address"),
						Attribute.getInteger(c, ctx, "size")));
			}
		}

		Map<String, Regions.Region> out = new LinkedHashMap<String, Regions.Region>();
		Map<Integer, Integer> cursor = new LinkedHashMap<Integer, Integer>();
		// what each page already holds, so an auto region can find a hole :
		// page -> list of [start, end) taken by a fixed region or a reserved range
		Map<Integer, java.util.List<int[]>> taken = new LinkedHashMap<Integer, java.util.List<int[]>>();
		java.util.List<ImmutableNode> deferred = new java.util.ArrayList<ImmutableNode>();
		// Every page some declaration starts on. A pages="auto" region with no
		// measure yet claims room up to the next one : generous enough that the
		// discovery pack never hits a ceiling, bounded so two of them never
		// overlap. The measure replaces it in the real pass.
		java.util.TreeSet<Integer> claimed = new java.util.TreeSet<Integer>();
		for (ImmutableNode c : layout.getChildren()) {
			if ("region".equals(c.getNodeName()) || "reserved".equals(c.getNodeName())) {
				// a region declaring zones names its pages there, one by one
				boolean fromZones = false;
				for (ImmutableNode z : c.getChildren()) {
					if ("zone".equals(z.getNodeName())) {
						claimed.add(Attribute.getInteger(z, ctx, "page"));
						fromZones = true;
					}
				}
				if (fromZones) {
					continue;
				}
				String p = Attribute.getStringOpt(c, ctx, "page");
				if (p != null && !"auto".equals(p)) {
					claimed.add(Attribute.getInteger(c, ctx, "page"));
				}
			}
		}
		// Pages the builder may range over for page="auto". Ordered : the
		// pages the author placed by hand come first, so an auto region fills
		// their tail before opening a fresh one — that tail is what the
		// occupancy report showed sitting unused.
		java.util.List<Integer> autoPages = new java.util.ArrayList<Integer>(claimed);
		String spare = Attribute.getStringOpt(layout, ctx, "sparepages");
		if (spare != null) {
			String[] bounds = spare.split("-");
			int from = Integer.decode(bounds[0].trim().replace("$", "0x"));
			int to = Integer.decode(bounds[bounds.length - 1].trim().replace("$", "0x"));
			for (int p = from; p <= to; p++) {
				if (!autoPages.contains(p)) {
					autoPages.add(p);
				}
			}
		}

		for (ImmutableNode child : layout.getChildren()) {

			if ("reserved".equals(child.getNodeName())) {
				int page = Attribute.getInteger(child, ctx, "page");
				int address = Attribute.getInteger(child, ctx, "address");
				int size = Attribute.getInteger(child, ctx, "size");
				bump(cursor, page, address + size);
				occupy(taken, page, address, size);
				continue;
			}
			if (!"region".equals(child.getNodeName())) {
				continue;    // the layout plugin reports what does not belong here
			}

			String name = Attribute.getString(child, ctx, "name");

			// Zones declared as children : the region says WHERE it lives, in
			// as many pieces as it needs. The compact form — page, address and
			// size on the element — is read further down and becomes a single
			// zone, so the rest of the builder sees one shape only.
			java.util.List<Regions.Zone> zones = new java.util.ArrayList<Regions.Zone>();
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
					occupy(taken, z.page, z.address, z.size);
					bump(cursor, z.page, z.end());
				}
				out.put(name, new Regions.Region(name, head.page, head.address, head.size,
						Attribute.getBoolean(child, ctx, "stacked", false), 1, zones));
				continue;
			}
			// The layout declares CONSTRAINTS, not decisions : what the author
			// does not write, the builder works out. An attribute that is
			// absent means "up to you" ; "auto" is still accepted, and says
			// the same thing out loud.
			String rawPage = Attribute.getStringOpt(child, ctx, "page");
			boolean autoPage = rawPage == null || "auto".equals(rawPage);
			int page = autoPage ? -1 : Attribute.getInteger(child, ctx, "page");

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
					// nothing declared above : the last region on the map may
					// claim up to the end of physical RAM (32 pages of 16K on
					// a 512K machine) — the measure replaces this next pass
					pages = next != null ? next - page : 32 - page;
				}
			}
			boolean stacked = Attribute.getBoolean(child, ctx, "stacked", false);

			String rawSize = Attribute.getStringOpt(child, ctx, "size");
			String rawAddress = Attribute.getStringOpt(child, ctx, "address");
			boolean autoSize = rawSize == null || "auto".equals(rawSize);
			boolean autoAddress = rawAddress == null || "auto".equals(rawAddress);

			// page="auto" is resolved in a second pass, once everything
			// placed by hand is known : a hole is only a hole when you can
			// see both of its edges.
			if (autoPage) {
				deferred.add(child);
				continue;
			}

			// First region of a page : it starts where the window opens. Only
			// a layout that declares no window still has to be told.
			if (autoAddress && !cursor.containsKey(page)) {
				Regions.Window w = ctx.regions.windowOf(windowStart(ctx));
				if (w == null) {
					throw new Exception(ctx.sources.locate(child) + ": region '" + name
							+ "' leaves its address to the builder but nothing precedes it on"
							+ " page " + page + " and the layout declares no <window> — a page"
							+ " does not say where it begins, so either give the address or"
							+ " declare the windows the machine sees its pages through");
				}
				bump(cursor, page, w.address);
			}
			int address = (autoAddress || autoPage) ? at(cursor, page)
					: Attribute.getInteger(child, ctx, "address");

			Integer size;
			if (!autoSize) {
				// a declared size is a BUDGET : the build refuses content that
				// outgrows it, which is the whole point of writing it down
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
			if (size != null) {
				for (int p = 0; p < pages; p++) {
					occupy(taken, page + p, pages > 1 ? 0 : address, pages > 1 ? PAGE_SIZE : size);
				}
			}

			if (pages > 1) {
				for (int p = 0; p < pages; p++) {
					bump(cursor, page + p, PAGE_SIZE);
				}
			} else if (size != null) {
				bump(cursor, page, address + size);
			}
		}
		// --- pass B : the regions that let the builder pick their page -----
		//
		// A hole is only a hole once both edges are known, so this runs after
		// everything placed by hand. First fit, declaration order : adding a
		// region must not move those already placed — every object is reached
		// through its page id, and a layout that reshuffles on each edit would
		// be impossible to reason about.
		for (ImmutableNode child : deferred) {
			String name = Attribute.getString(child, ctx, "name");

			// Zones declared as children : the region says WHERE it lives, in
			// as many pieces as it needs. The compact form — page, address and
			// size on the element — is read further down and becomes a single
			// zone, so the rest of the builder sees one shape only.
			java.util.List<Regions.Zone> zones = new java.util.ArrayList<Regions.Zone>();
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
					occupy(taken, z.page, z.address, z.size);
					bump(cursor, z.page, z.end());
				}
				out.put(name, new Regions.Region(name, head.page, head.address, head.size,
						Attribute.getBoolean(child, ctx, "stacked", false), 1, zones));
				continue;
			}
			Integer known = ctx.regions.measured(name);
			boolean stacked = Attribute.getBoolean(child, ctx, "stacked", false);

			if (known == null) {
				// discovery : nothing is measured yet and this pass is what
				// measures. A page of its own, past everything declared —
				// provisional, and never a refusal, or nothing gets measured.
				int fresh = 0;
				for (int c : taken.keySet()) {
					fresh = Math.max(fresh, c);
				}
				for (int c : autoPages) {
					fresh = Math.max(fresh, c);
				}
				int addr = windowStart(ctx);
				out.put(name, new Regions.Region(name, fresh + 1, addr, PAGE_SIZE, stacked, 1));
				occupy(taken, fresh + 1, addr, PAGE_SIZE);
				continue;
			}

			int[] spot = firstFit(taken, autoPages, ctx, known);
			if (spot == null) {
				throw new Exception(ctx.sources.locate(child) + ": region '" + name
						+ "' asks for page=\"auto\" but no page has " + known
						+ " free bytes in one run — widen the layout's sparepages, or make it"
						+ " a multi-page region a pageset fills");
			}
			out.put(name, new Regions.Region(name, spot[0], spot[1], known, stacked, 1));
			occupy(taken, spot[0], spot[1], known);
			bump(cursor, spot[0], spot[1] + known);
		}

		return out;
	}

	/** record a range as taken, so no auto region is offered it */
	private static void occupy(Map<Integer, java.util.List<int[]>> taken, int page, int address,
			int size) {
		taken.computeIfAbsent(page, p -> new java.util.ArrayList<int[]>())
		     .add(new int[] { address, address + size });
	}

	/**
	 * The first gap that fits, scanning the candidate pages in order : the
	 * pages the author placed by hand come first, so their unused tail is
	 * filled before a spare page is opened.
	 *
	 * @return {page, address} or null when nothing fits
	 */
	private static int[] firstFit(Map<Integer, java.util.List<int[]>> taken,
			java.util.List<Integer> candidates, BuildContext ctx, int need) {

		for (int page : candidates) {
			java.util.List<int[]> ranges = taken.get(page);
			// an untouched page : it opens where its window opens
			if (ranges == null || ranges.isEmpty()) {
				Regions.Window w = ctx.regions.windowOf(windowStart(ctx));
				int start = w != null ? w.address : 0;
				int top = w != null ? w.end() : PAGE_SIZE;
				if (start + need <= top) {
					return new int[] { page, start };
				}
				continue;
			}
			java.util.List<int[]> sorted = new java.util.ArrayList<int[]>(ranges);
			sorted.sort((a, b) -> Integer.compare(a[0], b[0]));
			Regions.Window w = ctx.regions.windowOf(sorted.get(0)[0]);
			int cursor = w != null ? w.address : 0;
			int top = w != null ? w.end() : PAGE_SIZE;
			for (int[] range : sorted) {
				if (range[0] - cursor >= need) {
					return new int[] { page, cursor };
				}
				cursor = Math.max(cursor, range[1]);
			}
			if (top - cursor >= need) {
				return new int[] { page, cursor };
			}
		}
		return null;
	}

	/**
	 * Where a fresh page opens : the first window the layout declares. A page
	 * is 16 KB but the CPU sees it somewhere — an auto-placed region landing
	 * on an empty page has to start at that somewhere, not at zero.
	 */
	private static int windowStart(BuildContext ctx) {
		java.util.List<Regions.Window> windows = ctx.regions.windows();
		return windows.isEmpty() ? 0 : windows.get(0).address;
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
