package com.widedot.toolbox.graphics.spritestream;

import java.util.Locale;

/**
 * One line of generated code with its size in bytes and its cycles, for the
 * instruction forms the walkers use : the layout places blocks into the gaps
 * between the aligned jump tables by their size (the assembler then checks the
 * place : a wrong size is a negative reservation, an error), and the opaque
 * segmentation compares routines by their cycles.
 *
 * Operands : {@code ,y} {@code 5,u} {@code -8192,y} (constant offsets : the
 * 5, 8 and 16 bit forms by value), {@code a,x} {@code b,y} {@code d,x}
 * (accumulator offsets), {@code [a,x]} {@code [b,x]} {@code [d,x]} (indirect),
 * {@code #n} (immediate), {@code <label} (direct page), a register list for
 * the stack instructions. Cycles of the 6809 data sheet, indexed extras
 * included (0 for {@code ,R}, 1 for a 5 or 8 bit offset or A/B, 4 for a 16
 * bit offset or D, 3 more indirect).
 */
final class Ins {

	final String label;
	final String op;
	final String arg;
	final int size;
	final int cycles;

	private Ins(String label, String op, String arg, int size, int cycles) {
		this.label = label;
		this.op = op;
		this.arg = arg;
		this.size = size;
		this.cycles = cycles;
	}

	/** a label line : no byte */
	static Ins label(String name) {
		return new Ins(name, null, null, 0, 0);
	}

	/** a data or reservation line whose size is known */
	static Ins data(String op, String arg, int size) {
		return new Ins(null, op, arg, size, 0);
	}

	/** a comment line : no byte */
	static Ins comment(String text) {
		return new Ins(null, "*", text, 0, 0);
	}

	/** an equate : no byte */
	static Ins equ(String name, String value) {
		return new Ins(name, "equ", value, 0, 0);
	}

	/** an instruction, measured from its mnemonic and operand */
	static Ins op(String op, String arg) {
		String o = op.toLowerCase(Locale.ROOT);
		int[] sc = measure(o, arg);
		return new Ins(null, o, arg, sc[0], sc[1]);
	}

	static Ins op(String op) {
		return op(op, "");
	}

	/** the text of the line, the prototype's layout (8 columns, operand at 15) */
	String text() {
		if (op == null) {
			return label;
		}
		if ("*".equals(op)) {
			return "* " + arg;
		}
		if ("equ".equals(op)) {
			return label + " equ " + arg;
		}
		String head = "        " + op;
		if (arg == null || arg.isEmpty()) {
			return head;
		}
		StringBuilder sb = new StringBuilder(head);
		while (sb.length() < 14) {
			sb.append(' ');
		}
		return sb.append(arg).toString();
	}

	// ---------------------------------------------------------------- model

	/** base cycles of the indexed form, and whether the opcode has a $10/$11 prefix */
	private static int[] indexedBase(String op) {
		switch (op) {
		case "lda": case "ldb": case "sta": case "stb":
		case "anda": case "andb": case "adda": case "addb":
		case "ora": case "orb": case "eora": case "eorb":
		case "suba": case "subb": case "cmpa": case "cmpb":
			return new int[] { 4, 0 };
		case "ldd": case "std": case "ldu": case "stu": case "ldx": case "stx":
			return new int[] { 5, 0 };
		case "addd": case "subd":
			return new int[] { 6, 0 };
		case "ldy": case "sty": case "lds": case "sts": case "cmpx":
			return new int[] { 6, "cmpx".equals(op) ? 0 : 1 };
		case "leax": case "leay": case "leau": case "leas":
			return new int[] { 4, 0 };
		case "jmp":
			return new int[] { 3, 0 };
		case "jsr":
			return new int[] { 7, 0 };
		default:
			throw new IllegalArgumentException("Ins : no indexed form for " + op);
		}
	}

	private static int[] measure(String op, String arg) {
		switch (op) {
		case "rts":
			return new int[] { 1, 5 };
		case "abx":
			return new int[] { 1, 3 };
		case "deca": case "decb": case "inca": case "incb":
			return new int[] { 1, 2 };
		case "pshs": case "puls": case "pshu": case "pulu":
			return new int[] { 2, 5 + stackBytes(arg) };
		default:
			break;
		}
		if (arg.startsWith("#")) {
			switch (op) {
			case "lda": case "ldb": case "anda": case "andb": case "adda": case "addb":
			case "ora": case "orb": case "suba": case "subb": case "cmpa": case "cmpb":
				return new int[] { 2, 2 };
			case "ldd": case "ldx": case "ldu":
				return new int[] { 3, 3 };
			case "addd": case "subd": case "cmpx":
				return new int[] { 3, 4 };
			case "ldy": case "lds":
				return new int[] { 4, 4 };
			case "cmpy":
				return new int[] { 4, 5 };
			default:
				throw new IllegalArgumentException("Ins : no immediate form for " + op);
			}
		}
		if (arg.startsWith("<")) {
			switch (op) {
			case "lda": case "ldb": case "sta": case "stb": case "adda": case "suba": case "cmpa":
				return new int[] { 2, 4 };
			case "ldd": case "std": case "ldx": case "stx": case "ldu": case "stu":
				return new int[] { 2, 5 };
			case "lds": case "sts": case "ldy": case "sty":
				return new int[] { 3, 6 };
			default:
				throw new IllegalArgumentException("Ins : no direct form for " + op);
			}
		}
		// indexed
		int[] base = indexedBase(op);
		boolean indirect = arg.startsWith("[");
		String a = indirect ? arg.substring(1, arg.length() - 1) : arg;
		int comma = a.indexOf(',');
		if (comma < 0) {
			throw new IllegalArgumentException("Ins : unknown operand " + arg + " for " + op);
		}
		String off = a.substring(0, comma).trim();
		int bytes, extra;
		if (off.isEmpty()) {
			bytes = 0;
			extra = indirect ? 3 : 0;
		} else if ("a".equals(off) || "b".equals(off)) {
			bytes = 0;
			extra = indirect ? 4 : 1;
		} else if ("d".equals(off)) {
			bytes = 0;
			extra = indirect ? 7 : 4;
		} else {
			int v = Integer.parseInt(off);
			if (v == 0) {
				bytes = 0;
				extra = indirect ? 3 : 0;
			} else if (v >= -16 && v <= 15 && !indirect) {
				bytes = 0;
				extra = 1;
			} else if (v >= -128 && v <= 127) {
				bytes = 1;
				extra = indirect ? 4 : 1;
			} else {
				bytes = 2;
				extra = indirect ? 7 : 4;
			}
		}
		return new int[] { 2 + base[1] + bytes, base[0] + extra };
	}

	private static int stackBytes(String regs) {
		int n = 0;
		for (String r : regs.split(",")) {
			switch (r.trim()) {
			case "a": case "b": case "cc": case "dp":
				n += 1;
				break;
			case "d": case "x": case "y": case "u": case "s": case "pc":
				n += 2;
				break;
			default:
				throw new IllegalArgumentException("Ins : unknown register " + r);
			}
		}
		return n;
	}
}
