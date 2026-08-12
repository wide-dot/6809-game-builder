package com.widedot.m6809.gamebuilder.spi.globals;

/**
 * What the builder needs to know about the target MACHINE, declared by the
 * configuration and never hard-coded here.
 *
 * The builder is machine-agnostic on purpose : it places bytes and resolves
 * names. Two facts nonetheless used to leak into its code — the page byte's
 * cartridge-window bits (once written as {@code map.RAM_OVER_CART+} or
 * {@code $60} by the generators) and the amount of RAM the occupancy report
 * draws. Both are properties of a TO8 or an MO6, not of the builder, and
 * both move the day another machine is targeted (MO5, CoCo 3).
 * They are declared in {@code engine/config/machine.xml} — one file holding
 * every machine, exactly like {@code storage.xml} holds every media — and
 * selected by {@code <machine name="…"/>} in the target.
 */
public class Machines {

	public static class Machine {
		public final String name;
		/** how many 16 KB pages of RAM the machine has ; the report's height */
		public final int ramPages;
		/**
		 * What a generated table writes in front of a page number so the byte
		 * can go straight to the window register — a NAME, never a value, so
		 * the number lives in one place only : the machine's own asm header.
		 */
		public final String pageExpr;
		/** the asm header defining {@link #pageExpr}, included by generated tables */
		public final String pageInclude;

		public Machine(String name, int ramPages, String pageExpr, String pageInclude) {
			this.name = name;
			this.ramPages = ramPages;
			this.pageExpr = pageExpr;
			this.pageInclude = pageInclude;
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
