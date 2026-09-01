package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.Collections;
import java.util.List;

/**
 * What the builder must know about the target MACHINE, declared by the
 * configuration and never hard-coded here.
 *
 * The builder is machine-agnostic on purpose : it places bytes and resolves
 * names. Three facts nonetheless belong to a TO8 or an MO6 rather than to the
 * builder — how much RAM it has, how that RAM is cut into pages, and through
 * which WINDOWS the processor sees it. All three are declared in
 * {@code engine/config/machine.xml} — one file holding every machine, exactly
 * like {@code storage.xml} holds every media — and selected by
 * {@code <machine name="…"/>} in the target.
 *
 * The windows are what lets the builder answer the only question it could
 * never answer before : two places reached through two different windows, are
 * they the same silicon ? See {@link WindowMap}.
 */
public class Machines {

	/**
	 * One position a window can show, when the window is SMALLER than a page :
	 * the video window shows 8 KB of a 16 KB page, so a CPU address does not
	 * say which half. {@code index} numbers the halves in the page's own
	 * order ; {@code value} is what the selector register must hold to show
	 * that half — and on the TO8 the two disagree, bit 1 showing the FIRST
	 * half. That inversion lives here and nowhere else.
	 */
	public static class Slice {
		public final int index;
		public final int value;

		public Slice(int index, int value) {
			this.index = index;
			this.value = value;
		}
	}

	/** What the processor sees, and how the page it shows is chosen. */
	public static class Window {
		public final String name;
		/** where the processor sees it */
		public final int address;
		/** how many bytes of it the processor sees */
		public final int size;
		/** the page it always shows, or null when a register chooses */
		public final Integer fixedPage;
		/** the register the runtime writes to choose the page, informational */
		public final String pageRegister;
		/**
		 * The NAME of the mask a generated table writes in front of a page
		 * number so the byte can go straight to the register — never a value,
		 * so the number stays in its single home, the machine's asm header.
		 */
		public final String or;
		/** the asm header defining {@link #or}, included by generated tables */
		public final String include;
		/** empty when the window is exactly one page wide */
		public final List<Slice> slices;

		public Window(String name, int address, int size, Integer fixedPage,
				String pageRegister, String or, String include, List<Slice> slices) {
			this.name = name;
			this.address = address;
			this.size = size;
			this.fixedPage = fixedPage;
			this.pageRegister = pageRegister;
			this.or = or;
			this.include = include;
			this.slices = slices == null ? Collections.<Slice>emptyList() : slices;
		}

		public boolean selectsPage() {
			return fixedPage == null;
		}

		public int end() {
			return address + size;
		}
	}

	public static class Machine {
		public final String name;
		/** how many pages of RAM the machine has ; the report's height */
		public final int ramPages;
		/** how many bytes in a page — 16 KB on a Thomson, 8 KB on a CoCo 3 */
		public final int pageSize;
		/**
		 * What a generated table writes in front of a page number. Kept while
		 * the generators still ask for it ; the window's {@code or} is its
		 * home now.
		 */
		public final String pageExpr;
		/** the asm header defining {@link #pageExpr} */
		public final String pageInclude;
		public final List<Window> windows;

		private WindowMap map;

		public Machine(String name, int ramPages, int pageSize, String pageExpr,
				String pageInclude, List<Window> windows) {
			this.name = name;
			this.ramPages = ramPages;
			this.pageSize = pageSize;
			this.pageExpr = pageExpr;
			this.pageInclude = pageInclude;
			this.windows = windows == null ? Collections.<Window>emptyList() : windows;
		}

		/** the arithmetic that turns a CPU address into silicon, and back */
		public WindowMap windows() {
			if (map == null) {
				map = new WindowMap(this);
			}
			return map;
		}
	}

	private Machine current;

	public void declare(Machine machine) {
		this.current = machine;
	}

	/** the machine this target builds for, or null when none was declared */
	public Machine current() {
		return current;
	}

	/**
	 * The machine, or a named error. Asked by whoever cannot do without it —
	 * a generator writing a page byte — so the message says what to declare
	 * rather than letting a null travel.
	 */
	public Machine required(String who) throws Exception {
		if (current == null) {
			throw new Exception(who + " needs the target machine : declare"
					+ " <machine name=\"to8\"/> (or mo6) in the target");
		}
		return current;
	}

	public void clear() {
		current = null;
	}
}
