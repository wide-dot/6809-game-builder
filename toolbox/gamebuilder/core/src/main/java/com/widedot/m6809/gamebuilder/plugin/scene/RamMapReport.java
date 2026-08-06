package com.widedot.m6809.gamebuilder.plugin.scene;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;

import com.widedot.m6809.gamebuilder.spi.globals.RamMap;
import com.widedot.m6809.gamebuilder.spi.globals.Regions;

/**
 * The memory occupancy map of each scene.
 *
 * Destinations in a v2 game are placed by hand against budgets worked out
 * once, and until now nothing said what those budgets left over. The map is
 * what you read before deciding where a new object goes : per page, in address
 * order, the declared regions and reserved ranges, the gaps between them, and
 * for every region the scene loads, how much of its budget is really used.
 *
 * It is drawn per scene, because a scene is what gets optimised. The whole
 * layout appears in each one — not only the regions that scene loads — because
 * a region's budget is reserved whether or not this particular composition
 * fills it, and it is against the budget that a new destination is placed. A
 * region the scene leaves alone is marked as such rather than shown free : its
 * content came from an earlier scene, and the builder does not know sequences.
 */
public final class RamMapReport {

	private RamMapReport() {
	}

	/** one drawn line of a page : a region, a reserved range, or a gap */
	private static class Row implements Comparable<Row> {
		final int address;
		final int size;
		final String kind;     // region | reserved | free
		final String name;
		String content;        // what the scene loads there, null when nothing
		int used;
		boolean stacked;

		Row(int address, int size, String kind, String name) {
			this.address = address;
			this.size = size;
			this.kind = kind;
			this.name = name;
		}

		public int compareTo(Row other) {
			return Integer.compare(address, other.address);
		}
	}

	public static String render(String targetName, RamMap map, Regions regions) {

		StringBuilder out = new StringBuilder();
		out.append("RAM occupancy of target ").append(targetName).append(System.lineSeparator());
		out.append("Declared layout, page by page, with what each scene loads into it.")
		   .append(System.lineSeparator());
		out.append("A region left alone by a scene keeps its budget : it holds what an earlier")
		   .append(System.lineSeparator());
		out.append("scene put there, which is not something the builder knows.")
		   .append(System.lineSeparator());

		for (Map.Entry<String, List<RamMap.Load>> scene : map.scenes().entrySet()) {

			// What this scene puts in each region, keyed by region AND page : a
			// pageset member lands on one page of its region, so summing the
			// whole set on every page would report a region several times full.
			// A stacked region stacks its loads on one page, and there the sum is
			// exactly what is wanted.
			Map<String, int[]> loadedSize = new LinkedHashMap<String, int[]>();   // key -> {bytes, count}
			Map<String, List<String>> loadedNames = new LinkedHashMap<String, List<String>>();
			List<RamMap.Load> raw = new ArrayList<RamMap.Load>();                 // no region
			for (RamMap.Load load : scene.getValue()) {
				if (load.region == null) {
					raw.add(load);
					continue;
				}
				String key = key(load.region, load.page);
				int[] cell = loadedSize.computeIfAbsent(key, r -> new int[2]);
				cell[0] += load.size;
				cell[1]++;
				loadedNames.computeIfAbsent(key, r -> new ArrayList<String>()).add(load.name);
			}

			out.append(System.lineSeparator());
			out.append("scene ").append(scene.getKey()).append(System.lineSeparator());
			out.append(line()).append(System.lineSeparator());

			// every page the layout declares something on
			TreeSet<Integer> pages = new TreeSet<Integer>();
			for (Regions.Region region : regions.all()) {
				for (int p = region.page; p < region.page + region.pages; p++) {
					pages.add(p);
				}
			}
			for (Regions.Reserved reserved : regions.reservedRanges()) {
				pages.add(reserved.page);
			}
			for (RamMap.Load load : raw) {
				pages.add(load.page);
			}

			int freeTotal = 0;
			for (int page : pages) {
				List<Row> rows = new ArrayList<Row>();

				for (Regions.Region region : regions.all()) {
					if (region.size == null || page < region.page
							|| page >= region.page + region.pages) {
						continue;
					}
					Row row = new Row(region.address, region.size, "region", region.name);
					int[] cell = loadedSize.get(key(region.name, page));
					if (cell != null) {
						row.used = cell[0];
						row.stacked = region.stacked || cell[1] > 1;
						List<String> names = loadedNames.get(key(region.name, page));
						row.content = names.size() == 1 ? names.get(0) : names.size() + " files";
					}
					rows.add(row);
				}
				for (Regions.Reserved reserved : regions.reservedRanges()) {
					if (reserved.page == page) {
						rows.add(new Row(reserved.address, reserved.size, "reserved", reserved.name));
					}
				}
				for (RamMap.Load load : raw) {
					if (load.page == page) {
						Row row = new Row(load.address, load.size, "raw", load.name);
						row.used = load.size;
						row.content = load.name;
						rows.add(row);
					}
				}
				if (rows.isEmpty()) {
					continue;
				}
				rows.sort(Comparator.naturalOrder());

				out.append(String.format("page $%02X", page)).append(System.lineSeparator());
				int cursor = -1;
				for (Row row : rows) {
					if (cursor >= 0 && row.address > cursor) {
						out.append(String.format("  $%04X-$%04X  %-9s %-22s %6d",
								cursor, row.address - 1, "free", "", row.address - cursor))
						   .append(System.lineSeparator());
					}
					out.append(String.format("  $%04X-$%04X  %-9s %-22s %6d",
							row.address, row.address + row.size - 1, row.kind, row.name, row.size));
					if (row.content != null) {
						out.append(String.format("  %-28s %6d  %3d%%%s", row.content, row.used,
								row.size == 0 ? 0 : row.used * 100 / row.size,
								row.stacked ? "  stacked" : ""));
					} else if ("region".equals(row.kind)) {
						out.append("  (not loaded by this scene)");
					}
					out.append(System.lineSeparator());
					cursor = Math.max(cursor, row.address + row.size);
				}
				// What is left above the last declaration. The report used to
				// stop at "declared up to", which said nothing : with
				// size="auto" every region fills itself, so the percentages
				// all read 100% while whole kilobytes sat free above them.
				// Needs the layout to declare its windows — a page is 16 KB
				// but WHERE it is seen belongs to the machine.
				Regions.Window window = regions.windowOf(rows.get(0).address);
				if (window != null && cursor < window.end()) {
					int free = window.end() - cursor;
					out.append(String.format("  $%04X-$%04X  %-9s %-22s %6d",
							cursor, window.end() - 1, "free", "(end of page)", free))
					   .append(System.lineSeparator());
					freeTotal += free;
				}
				out.append(String.format("  declared up to $%04X", cursor))
				   .append(System.lineSeparator());
			}
			if (!regions.windows().isEmpty()) {
				out.append(String.format("free at the top of the declared pages : %d bytes",
						freeTotal)).append(System.lineSeparator());
			}
		}
		return out.toString();
	}

	/** a region occupies one page of its budget at a time : both name the cell */
	private static String key(String region, int page) {
		return region + "@" + page;
	}

	private static String line() {
		StringBuilder dashes = new StringBuilder();
		for (int i = 0; i < 78; i++) {
			dashes.append('-');
		}
		return dashes.toString();
	}
}
