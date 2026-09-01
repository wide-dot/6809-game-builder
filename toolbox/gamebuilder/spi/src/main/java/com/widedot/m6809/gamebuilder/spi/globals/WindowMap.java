package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.ArrayList;
import java.util.List;

/**
 * The arithmetic between what the author writes and what the silicon is.
 *
 * The author writes two numbers : the PAGE a resource lives in, and the
 * ADDRESS it executes at — the one the code itself uses. Everything else is
 * computed here :
 *
 * <ul>
 * <li>which WINDOW shows that address (the machine's windows occupy disjoint
 *     CPU ranges, so an address names one and only one) ;</li>
 * <li>the POSITION of the resource inside its page, which is the referential
 *     collisions are detected in — and which nobody ever writes ;</li>
 * <li>the SELECTOR value the runtime must put in the window's register.</li>
 * </ul>
 *
 * The position is {@code (base + address − window.address) mod pageSize},
 * where {@code base} is the window's own offset in a page. On a TO8 that
 * reduces to «&nbsp;the low 14 bits of the CPU address ARE the position&nbsp;» :
 * the video window is only 8 KB, so it pushes what follows off the 16 KB
 * grid and {@code $6000} lands in the middle of a page. What the emulator's
 * documentation calls a non-linear order is that, and nothing more.
 *
 * A place may therefore run past the END of its page and continue at its
 * start — the nine screens of r-type do, loaded at {@code $7C00} and longer
 * than {@code $0400}. The processor sees one contiguous run ; the page sees
 * two pieces. {@link #footprint} returns both.
 */
public final class WindowMap {

	private final Machines.Machine machine;

	public WindowMap(Machines.Machine machine) {
		this.machine = machine;
	}

	public int pageSize() {
		return machine.pageSize;
	}

	/** The window showing this CPU address, or an error listing what exists. */
	public Machines.Window of(int cpu) throws Exception {
		for (Machines.Window w : machine.windows) {
			if (cpu >= w.address && cpu < w.end()) {
				return w;
			}
		}
		StringBuilder known = new StringBuilder();
		for (Machines.Window w : machine.windows) {
			known.append(known.length() == 0 ? "" : ", ").append(w.name).append(" $")
					.append(hex(w.address)).append("-$").append(hex(w.end() - 1));
		}
		throw new Exception("$" + hex(cpu) + " is in no window of machine '" + machine.name
				+ "' (it declares: " + known + ")");
	}

	/**
	 * A place must stay inside the window it starts in : a 8 KB cartridge file
	 * at {@code $3000} would spill into the video window and write on screen.
	 * Running past the page's end is legal ; running past the window's is not.
	 */
	public void checkFits(Machines.Window w, int cpu, int size) throws Exception {
		if (size > machine.pageSize) {
			throw new Exception("a place of $" + hex(size) + " bytes cannot fit in a page of $"
					+ hex(machine.pageSize));
		}
		if (cpu + size > w.end()) {
			throw new Exception("$" + hex(cpu) + " + $" + hex(size) + " runs past the '" + w.name
					+ "' window, which ends at $" + hex(w.end())
					+ " — the bytes beyond would land in another window");
		}
	}

	/** The window's own offset in the page it shows. */
	private int base(Machines.Window w, Integer slice) throws Exception {
		if (w.slices.isEmpty()) {
			if (slice != null) {
				throw new Exception("window '" + w.name + "' shows a whole page: it takes no slice");
			}
			return Math.floorMod(w.address, machine.pageSize);
		}
		if (slice == null) {
			throw new Exception("window '" + w.name + "' shows only $" + hex(w.size)
					+ " of a page of $" + hex(machine.pageSize)
					+ ": say which slice of the page (0.." + (w.slices.size() - 1) + ")");
		}
		for (Machines.Slice s : w.slices) {
			if (s.index == slice.intValue()) {
				return s.index * w.size;
			}
		}
		throw new Exception("window '" + w.name + "' has no slice " + slice
				+ " (it declares 0.." + (w.slices.size() - 1) + ")");
	}

	/** Where this address lands inside the page the window shows. */
	public int positionOf(Machines.Window w, int cpu, Integer slice) throws Exception {
		return Math.floorMod(base(w, slice) + (cpu - w.address), machine.pageSize);
	}

	/** The address at which the window shows that position of its page. */
	public int cpuOf(Machines.Window w, int position) throws Exception {
		Integer slice = w.slices.isEmpty() ? null : Integer.valueOf(position / w.size);
		return w.address + Math.floorMod(position - base(w, slice), machine.pageSize);
	}

	/**
	 * The value the window's selector must hold — the page number for a window
	 * that pages, the slice's own value otherwise. The cartridge mask is NOT
	 * added here : it is a name, added by whoever writes the table.
	 */
	public int selectorOf(Machines.Window w, Integer page, Integer slice) throws Exception {
		if (w.selectsPage()) {
			if (page == null) {
				throw new Exception("window '" + w.name + "' pages through " + w.pageRegister
						+ ": a page is needed");
			}
			if (page < 0 || page >= machine.ramPages) {
				throw new Exception("page $" + hex(page) + " is outside the " + machine.ramPages
						+ " pages of machine '" + machine.name + "'");
			}
			return page.intValue();
		}
		if (page != null && page.intValue() != w.fixedPage.intValue()) {
			throw new Exception("window '" + w.name + "' is a window on page "
					+ w.fixedPage + ": it cannot show page $" + hex(page));
		}
		if (w.slices.isEmpty()) {
			return w.fixedPage.intValue();
		}
		for (Machines.Slice s : w.slices) {
			if (s.index == (slice == null ? -1 : slice.intValue())) {
				return s.value;
			}
		}
		base(w, slice); // raises the named error
		return 0;
	}

	/** The page a place lives in, whether the author wrote it or the window fixes it. */
	public int pageOf(Machines.Window w, Integer page) throws Exception {
		if (!w.selectsPage()) {
			if (page != null && page.intValue() != w.fixedPage.intValue()) {
				throw new Exception("window '" + w.name + "' is a window on page "
						+ w.fixedPage + ": it cannot show page $" + hex(page));
			}
			return w.fixedPage.intValue();
		}
		if (page == null) {
			throw new Exception("window '" + w.name + "' pages through " + w.pageRegister
					+ ": a page is needed");
		}
		return page.intValue();
	}

	/**
	 * The absolute physical bytes a place occupies — two ranges when it runs
	 * past the end of its page and continues at the start of the same page.
	 * Each range is {@code {first, last+1}}.
	 */
	public List<int[]> footprint(Machines.Window w, Integer page, int cpu, int size, Integer slice)
			throws Exception {
		checkFits(w, cpu, size);
		int origin = pageOf(w, page) * machine.pageSize;
		int position = positionOf(w, cpu, slice);
		List<int[]> ranges = new ArrayList<int[]>(2);
		if (position + size <= machine.pageSize) {
			ranges.add(new int[] { origin + position, origin + position + size });
		} else {
			ranges.add(new int[] { origin + position, origin + machine.pageSize });
			ranges.add(new int[] { origin, origin + position + size - machine.pageSize });
		}
		return ranges;
	}

	/**
	 * A place, once the window has had its say : which silicon it occupies,
	 * and which byte the runtime must write to see it.
	 */
	public static final class Placement {
		/** the window the address falls in */
		public final Machines.Window window;
		/** the page it really lives in */
		public final int page;
		/** where it starts inside that page — the referential of every check */
		public final int position;
		/** what the window's selector must hold, which is what tables carry */
		public final int selector;
		/** which slice of the page, when the window shows less than one */
		public final Integer slice;

		Placement(Machines.Window window, int page, int position, int selector, Integer slice) {
			this.window = window;
			this.page = page;
			this.position = position;
			this.selector = selector;
			this.slice = slice;
		}
	}

	/**
	 * Resolve a declared place — the page it lives in, the address it runs at,
	 * and which slice when the window shows less than a page.
	 *
	 * <p><b>The legacy spelling.</b> Before the windows were declared, a place
	 * in the video window wrote the SELECTOR where a page goes :
	 * {@code page="$01" address="$4000"} meant «&nbsp;half-page 1&nbsp;», not
	 * page 1. That reading is still accepted and translated here, so no
	 * configuration had to change the day the model arrived. It goes when the
	 * declarations do.
	 *
	 * @param size the declared size, or null when it is not known yet
	 */
	public Placement resolve(Integer page, int cpu, Integer slice, Integer size)
			throws Exception {
		Machines.Window w = of(cpu);
		Integer usedSlice = slice;
		Integer usedPage = page;
		if (!w.slices.isEmpty() && slice == null && page != null
				&& page.intValue() != w.fixedPage.intValue()) {
			usedSlice = legacySlice(w, page.intValue());
			usedPage = null;
		}
		if (size != null) {
			checkFits(w, cpu, size.intValue());
		}
		int resolvedPage = pageOf(w, usedPage);
		return new Placement(w, resolvedPage, positionOf(w, cpu, usedSlice),
				selectorOf(w, usedPage, usedSlice), usedSlice);
	}

	/** the slice a legacy selector value named */
	private Integer legacySlice(Machines.Window w, int selector) throws Exception {
		for (Machines.Slice s : w.slices) {
			if (s.value == selector) {
				return Integer.valueOf(s.index);
			}
		}
		throw new Exception("window '" + w.name + "' is a window on page " + w.fixedPage
				+ ": '" + selector + "' is neither that page nor one of its selector values");
	}

	/**
	 * The absolute bytes a DECLARED place occupies : resolve it through its
	 * window, then take its footprint. This is what every overlap check
	 * compares — two places collide when their physical bytes do, whatever
	 * window each is reached through.
	 */
	public List<int[]> footprint(Integer page, int cpu, int size, Integer slice)
			throws Exception {
		Placement p = resolve(page, cpu, slice, Integer.valueOf(size));
		return footprint(p.window, Integer.valueOf(p.page), cpu, size, p.slice);
	}

	/** whether two footprints touch the same byte */
	public static boolean overlap(List<int[]> a, List<int[]> b) {
		for (int[] x : a) {
			for (int[] y : b) {
				if (x[0] < y[1] && y[0] < x[1]) {
					return true;
				}
			}
		}
		return false;
	}

	/**
	 * A footprint as the messages spell it : the page, and the position inside
	 * it — two pieces when the place runs past the page's end and comes back
	 * to its start.
	 */
	public String describe(List<int[]> ranges) {
		StringBuilder out = new StringBuilder();
		for (int[] r : ranges) {
			out.append(out.length() == 0 ? "" : " + ")
					.append(String.format("page %d +$%04X-$%04X", r[0] / machine.pageSize,
							r[0] % machine.pageSize, (r[1] - 1) % machine.pageSize));
		}
		return out.toString();
	}

	private static String hex(int v) {
		return String.format("%04X", v);
	}
}
