package com.widedot.toolbox.graphics.backlines;

import java.awt.image.BufferedImage;
import java.awt.image.IndexColorModel;
import java.awt.image.Raster;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * A background picture compiled line by line, drawable from any of its lines
 * to any other, at any line of the screen : a fixed background behind a
 * tilemap that redraws only the part the tiles leave visible, and moves it
 * vertically (a differential scroll) by choosing which of its lines go where.
 *
 * The picture is BM16 (two pixels a byte, PNG index = colour + 1, every
 * pixel opaque, a width multiple of 4) : its first plane holds pixels 4k and
 * 4k+1 of each group of four, the second, planedistance bytes below it, 4k+2
 * and 4k+3. In half-line, its even lines alone are drawn, one screen line in
 * two.
 *
 * Each plane is one chain of code, a block a drawn line, bottom up : the
 * block pushes the line's bytes with PSHU from its right end (the bytes held
 * as immediate values in A, B, DP, X and Y), then moves U to the right end of
 * the line above (a short LEAU). A beam search over the chain chooses how
 * each line is cut into pushes and which values stay in the registers from a
 * line to the next, for the fewest cycles. The chain is entered at any line
 * through that line's entry, which loads the registers its block expects
 * from the lines below ; it runs up to an RTS : after the picture's first
 * line, or written by the caller at the start of the block above the last
 * line wanted, and put back after.
 *
 * Generated : {@code <label>_Draw} (A the bottom line, B the top line, both
 * picture drawn lines from 0 at the top ; X the screen address just right of
 * the bottom line's first plane bytes ; draws both planes, DP used as a data
 * register and not restored), the tables {@code <label>_Lines1/2} (each
 * block's start) and {@code <label>_Entries1/2}, and {@code <label>_LINES},
 * {@code <label>_BYTES} (bytes a plane line).
 */
public final class BackLines {

	static final String[] REGS = { "A", "B", "DP", "X", "Y" };
	static final int[] SIZE = { 1, 1, 1, 2, 2 };
	/** register subsets (indexes into REGS, memory order) by the bytes they push */
	static final List<List<int[]>> SUBS = new ArrayList<List<int[]>>();
	static {
		for (int s = 0; s <= 7; s++) {
			SUBS.add(new ArrayList<int[]>());
		}
		for (int mask = 1; mask < 32; mask++) {
			int n = 0, size = 0;
			for (int r = 0; r < 5; r++) {
				if ((mask & 1 << r) != 0) {
					n++;
					size += SIZE[r];
				}
			}
			int[] sub = new int[n];
			for (int r = 0, i = 0; r < 5; r++) {
				if ((mask & 1 << r) != 0) {
					sub[i++] = r;
				}
			}
			SUBS.get(size).add(sub);
		}
	}

	/** One push : the line (in chain order), the registers, the bytes. */
	static final class Push {
		final int line;
		final int[] sub;
		final int[] bytes;

		Push(int line, int[] sub, int[] bytes) {
			this.line = line;
			this.sub = sub;
			this.bytes = bytes;
		}
	}

	/** What the conversion produces. */
	public static final class Result {
		public final String source;
		public final int lines;
		public final int bytes;
		public final int size;
		public final int cycles;

		Result(String source, int lines, int bytes, int size, int cycles) {
			this.source = source;
			this.lines = lines;
			this.bytes = bytes;
			this.size = size;
			this.cycles = cycles;
		}
	}

	private BackLines() {
	}

	/** the values sub pushes of the bytes */
	static long[] needed(int[] sub, int[] bytes) {
		long[] v = new long[5];
		int i = 0;
		for (int r : sub) {
			if (SIZE[r] == 1) {
				v[r] = bytes[i++];
			} else {
				v[r] = bytes[i] << 8 | bytes[i + 1];
				i += 2;
			}
		}
		return v;
	}

	static long reg(long state, int r) {
		switch (r) {
		case 0: return state >>> 48 & 0xFF;
		case 1: return state >>> 40 & 0xFF;
		case 2: return state >>> 32 & 0xFF;
		case 3: return state >>> 16 & 0xFFFF;
		default: return state & 0xFFFF;
		}
	}

	static long with(long state, int r, long v) {
		int shift = r == 0 ? 48 : r == 1 ? 40 : r == 2 ? 32 : r == 3 ? 16 : 0;
		long mask = (SIZE[r] == 1 ? 0xFFL : 0xFFFFL) << shift;
		return state & ~mask | v << shift;
	}

	/** the loads before a push : their code, cycles and bytes, the state after */
	static final class Loads {
		final List<String> code = new ArrayList<String>();
		int cycles, size;
		long state;
		final Set<Integer> wrote = new HashSet<Integer>();
	}

	static boolean has(int[] sub, int r) {
		for (int x : sub) {
			if (x == r) {
				return true;
			}
		}
		return false;
	}

	static Loads loads(long state, int[] sub, int[] bytes) {
		Loads l = new Loads();
		long[] need = needed(sub, bytes);
		long st = state;
		if (has(sub, 2) && need[2] != reg(st, 2)) {
			int t = has(sub, 1) ? 0 : 1;               // DP through B, or A when B is pushed too
			l.code.add(String.format("ld%s   #$%02X", t == 0 ? "a" : "b", need[2]));
			l.code.add(String.format("tfr   %s,dp", t == 0 ? "a" : "b"));
			l.cycles += 8;
			l.size += 4;
			st = with(with(st, t, need[2]), 2, need[2]);
			l.wrote.add(t);
			l.wrote.add(2);
		}
		boolean la = has(sub, 0) && need[0] != reg(st, 0);
		boolean lb = has(sub, 1) && need[1] != reg(st, 1);
		if (la && lb) {
			l.code.add(String.format("ldd   #$%02X%02X", need[0], need[1]));
			l.cycles += 3;
			l.size += 3;
		} else if (la) {
			l.code.add(String.format("lda   #$%02X", need[0]));
			l.cycles += 2;
			l.size += 2;
		} else if (lb) {
			l.code.add(String.format("ldb   #$%02X", need[1]));
			l.cycles += 2;
			l.size += 2;
		}
		if (la) {
			l.wrote.add(0);
		}
		if (lb) {
			l.wrote.add(1);
		}
		for (int r = 0; r < 2; r++) {
			if (has(sub, r)) {
				st = with(st, r, need[r]);
			}
		}
		if (has(sub, 3) && need[3] != reg(st, 3)) {
			l.code.add(String.format("ldx   #$%04X", need[3]));
			l.cycles += 3;
			l.size += 3;
			st = with(st, 3, need[3]);
			l.wrote.add(3);
		}
		if (has(sub, 4) && need[4] != reg(st, 4)) {
			l.code.add(String.format("ldy   #$%04X", need[4]));
			l.cycles += 4;
			l.size += 4;
			st = with(st, 4, need[4]);
			l.wrote.add(4);
		}
		l.state = st;
		return l;
	}

	static String push(int[] sub) {
		List<String> regs = new ArrayList<String>();
		if (has(sub, 0) && has(sub, 1)) {
			regs.add("d");
		} else if (has(sub, 0)) {
			regs.add("a");
		} else if (has(sub, 1)) {
			regs.add("b");
		}
		for (int r : sub) {
			if (r >= 2) {
				regs.add(REGS[r].toLowerCase());
			}
		}
		return "pshu  " + String.join(",", regs);
	}

	static int pushCycles(int[] sub) {
		int n = 5;
		for (int r : sub) {
			n += SIZE[r];
		}
		return n;
	}

	/** LEAU n,U : bytes and cycles by the offset's size */
	static int leaSize(int n) {
		return n >= -16 && n <= 15 ? 2 : n >= -128 && n <= 127 ? 3 : 4;
	}

	static int leaCycles(int n) {
		return n >= -16 && n <= 15 ? 5 : n >= -128 && n <= 127 ? 5 : 8;
	}

	static final class Node {
		final int cost;
		final Node parent;
		final Push push;

		Node(int cost, Node parent, Push push) {
			this.cost = cost;
			this.parent = parent;
			this.push = push;
		}
	}

	/** the cheapest cut of a chain's lines into pushes, in chain order */
	static List<Push> plan(List<int[]> lines, int step, int beam) {
		Map<Long, Node> front = new HashMap<Long, Node>();
		front.put(0L, new Node(0, null, null));
		for (int li = 0; li < lines.size(); li++) {
			int[] b = lines.get(li);
			Map<Integer, Map<Long, Node>> at = new HashMap<Integer, Map<Long, Node>>();
			at.put(b.length, front);
			for (int p = b.length; p > 0; p--) {
				Map<Long, Node> f = at.remove(p);
				if (f == null || f.isEmpty()) {
					continue;
				}
				List<Map.Entry<Long, Node>> entries = new ArrayList<Map.Entry<Long, Node>>(f.entrySet());
				entries.sort((x, y) -> x.getValue().cost != y.getValue().cost
						? Integer.compare(x.getValue().cost, y.getValue().cost)
						: Long.compare(x.getKey(), y.getKey()));
				if (entries.size() > beam) {
					entries = entries.subList(0, beam);
				}
				for (Map.Entry<Long, Node> e : entries) {
					for (int size = 1; size <= Math.min(7, p); size++) {
						int[] ch = java.util.Arrays.copyOfRange(b, p - size, p);
						for (int[] sub : SUBS.get(size)) {
							Loads l = loads(e.getKey(), sub, ch);
							int cost = e.getValue().cost + l.cycles + pushCycles(sub);
							Map<Long, Node> d = at.computeIfAbsent(p - size, k -> new HashMap<Long, Node>());
							Node old = d.get(l.state);
							if (old == null || cost < old.cost) {
								d.put(l.state, new Node(cost, e.getValue(), new Push(li, sub, ch)));
							}
						}
					}
				}
			}
			Map<Long, Node> next = new HashMap<Long, Node>();
			for (Map.Entry<Long, Node> e : at.get(0).entrySet()) {
				next.put(e.getKey(), new Node(e.getValue().cost + leaCycles(step), e.getValue().parent, e.getValue().push));
			}
			front = next;
		}
		Node best = null;
		for (Node n : front.values()) {
			if (best == null || n.cost < best.cost) {
				best = n;
			}
		}
		List<Push> out = new ArrayList<Push>();
		for (Node n = best; n.push != null; n = n.parent) {
			out.add(0, n.push);
		}
		return out;
	}

	/** the registers pushes[start..] push before loading them, replayed from state */
	static Set<Integer> liveIn(List<Push> pushes, int start, long state) {
		Set<Integer> live = new HashSet<Integer>(), dead = new HashSet<Integer>();
		for (int i = start; i < pushes.size(); i++) {
			Push p = pushes.get(i);
			Loads l = loads(state, p.sub, p.bytes);
			state = l.state;
			for (int r : p.sub) {
				if (!dead.contains(r) && !l.wrote.contains(r)) {
					live.add(r);
				}
			}
			dead.addAll(l.wrote);
			for (int r : p.sub) {
				dead.add(r);
			}
			if (dead.size() == 5) {
				break;
			}
		}
		return live;
	}

	/**
	 * @param im            BM16 picture : PNG index = colour + 1, every pixel opaque, width multiple of 4
	 * @param label         prefix of the generated symbols
	 * @param halfline      its even lines alone are drawn, one screen line in two
	 * @param linebytes     bytes a screen line, a plane
	 * @param planedistance the second plane, bytes below the first
	 * @param beam          the search's width (60 : tools/ehz_back.py's)
	 */
	public static Result compile(BufferedImage im, String label, boolean halfline, int linebytes,
			int planedistance, int beam) throws Exception {
		if (!(im.getColorModel() instanceof IndexColorModel)) {
			throw new Exception("backlines " + label + " : the picture must be an indexed PNG");
		}
		if (im.getWidth() % 4 != 0) {
			throw new Exception("backlines " + label + " : " + im.getWidth()
					+ " pixels wide, not a multiple of 4 (a byte of each plane)");
		}
		int step = halfline ? 2 : 1;
		if (halfline && im.getHeight() % 2 != 0) {
			throw new Exception("backlines " + label + " : " + im.getHeight() + " lines, half-line wants an even count");
		}
		Raster r = im.getRaster();
		int bytes = im.getWidth() / 4;
		int n = (im.getHeight() + step - 1) / step;
		// drawn line i (0 at the top) : picture line i * step ; its two planes' bytes
		int[][][] planes = new int[2][n][bytes];
		for (int i = 0; i < n; i++) {
			int y = i * step;
			for (int k = 0; k < bytes; k++) {
				int[] p = new int[4];
				for (int d = 0; d < 4; d++) {
					p[d] = r.getSample(4 * k + d, y, 0);
					if (p[d] == 0) {
						throw new Exception("backlines " + label + " : a transparent pixel at (" + (4 * k + d) + "," + y
								+ ") ; a background covers what it draws, give it a colour");
					}
					if (p[d] > 16) {
						throw new Exception("backlines " + label + " : PNG index " + p[d] + " at (" + (4 * k + d) + "," + y
								+ "), BM16 has 16 colours (index = colour + 1)");
					}
				}
				planes[0][i][k] = (p[0] - 1) << 4 | (p[1] - 1);
				planes[1][i][k] = (p[2] - 1) << 4 | (p[3] - 1);
			}
		}
		int up = -(linebytes * step - bytes);          // U from a line's left end to the right end of the line above

		StringBuilder s = new StringBuilder();
		String nl = System.lineSeparator();
		int size = 0, cycles = 0;
		s.append("* Generated by <backlines> -- do not edit.").append(nl);
		s.append("* ").append(n).append(" drawn lines of ").append(bytes).append(" bytes a plane, bottom up a chain a plane").append(nl);
		s.append(" SECTION code").append(nl);
		s.append(label).append("_LINES equ ").append(n).append(nl);
		s.append(label).append("_BYTES equ ").append(bytes).append(nl).append(nl);
		size += draw(s, label, planedistance, nl);

		StringBuilder chains = new StringBuilder(), stubs = new StringBuilder();
		for (int c = 0; c < 2; c++) {
			// chain order : bottom up
			List<int[]> lines = new ArrayList<int[]>();
			for (int i = n - 1; i >= 0; i--) {
				lines.add(planes[c][i]);
			}
			List<Push> pushes = plan(lines, up, beam);
			Map<Integer, List<Integer>> byLine = new LinkedHashMap<Integer, List<Integer>>();
			for (int i = 0; i < pushes.size(); i++) {
				byLine.computeIfAbsent(pushes.get(i).line, k -> new ArrayList<Integer>()).add(i);
			}
			long state = 0;
			long[] startState = new long[n];
			int[] firstPush = new int[n];
			s.append(label).append("_Lines").append(c + 1).append(nl);
			for (int i = 0; i < n; i++) {
				s.append("        fdb   ").append(label).append('_').append(c + 1).append('_').append(i).append(nl);
				size += 2;
			}
			s.append(label).append("_Entries").append(c + 1).append(nl);
			for (int i = 0; i < n; i++) {
				s.append("        fdb   ").append(label).append("_E").append(c + 1).append('_').append(i).append(nl);
				size += 2;
			}
			for (int li = 0; li < n; li++) {
				int line = n - 1 - li;                  // the picture's drawn line
				startState[line] = state;
				firstPush[line] = byLine.get(li).get(0);
				chains.append(label).append('_').append(c + 1).append('_').append(line).append(nl);
				for (int i : byLine.get(li)) {
					Push p = pushes.get(i);
					Loads l = loads(state, p.sub, p.bytes);
					for (String code : l.code) {
						chains.append("        ").append(code).append(nl);
					}
					chains.append("        ").append(push(p.sub)).append(nl);
					size += l.size + 2;
					cycles += l.cycles + pushCycles(p.sub);
					state = l.state;
				}
				chains.append("        leau  ").append(up).append(",u").append(nl);
				size += leaSize(up);
				cycles += leaCycles(up);
			}
			chains.append("        rts                      ; after the picture's first line").append(nl);
			size += 1;
			for (int line = 0; line < n; line++) {
				Set<Integer> live = liveIn(pushes, firstPush[line], startState[line]);
				long st = startState[line];
				stubs.append(label).append("_E").append(c + 1).append('_').append(line).append(nl);
				if (live.contains(2)) {
					stubs.append(String.format("        lda   #$%02X%n        tfr   a,dp%n", reg(st, 2)));
					size += 4;
				}
				if (live.contains(0) && live.contains(1)) {
					stubs.append(String.format("        ldd   #$%02X%02X%n", reg(st, 0), reg(st, 1)));
					size += 3;
				} else if (live.contains(0)) {
					stubs.append(String.format("        lda   #$%02X%n", reg(st, 0)));
					size += 2;
				} else if (live.contains(1)) {
					stubs.append(String.format("        ldb   #$%02X%n", reg(st, 1)));
					size += 2;
				}
				if (live.contains(3)) {
					stubs.append(String.format("        ldx   #$%04X%n", reg(st, 3)));
					size += 3;
				}
				if (live.contains(4)) {
					stubs.append(String.format("        ldy   #$%04X%n", reg(st, 4)));
					size += 4;
				}
				stubs.append("        jmp   ").append(label).append('_').append(c + 1).append('_').append(line).append(nl);
				size += 3;
			}
		}
		s.append(nl).append(chains).append(nl).append(stubs);
		s.append(" ENDSECTION").append(nl);
		return new Result(s.toString(), n, bytes, size, cycles);
	}

	/**
	 * Standalone : image=<png> label=<label> gensource=<asm> [halfline=true]
	 * [linebytes=40] [planedistance=8192] [beam=60]
	 */
	public static void main(String[] args) throws Exception {
		Map<String, String> a = new HashMap<String, String>();
		for (String arg : args) {
			a.put(arg.substring(0, arg.indexOf('=')), arg.substring(arg.indexOf('=') + 1));
		}
		BufferedImage im = javax.imageio.ImageIO.read(new java.io.File(a.get("image")));
		Result r = compile(im, a.get("label"), Boolean.parseBoolean(a.getOrDefault("halfline", "false")),
				Integer.decode(a.getOrDefault("linebytes", "40")), Integer.decode(a.getOrDefault("planedistance", "8192")),
				Integer.decode(a.getOrDefault("beam", "60")));
		java.nio.file.Files.writeString(java.nio.file.Paths.get(a.get("gensource")), r.source);
		System.out.println("backlines " + a.get("label") + " : " + r.lines + " drawn lines, " + r.size + " bytes, "
				+ r.cycles + " cycles for every line");
	}

	/** the drawing routine, both chains, the stop written and taken back ; its bytes */
	static int draw(StringBuilder s, String label, int planedistance, String nl) {
		String l = label;
		String[] code = {
			"* " + l + "_Draw : the picture's drawn lines B (top) to A (bottom), both counted",
			"* from 0 at the top, the bottom one drawn at the screen line whose first",
			"* plane ends just left of X ; bottom up, both planes. DP is a data register",
			"* here : the caller keeps it",
			l + "_Draw",
			"        std   >" + l + "_ab",
			"        stx   >" + l + "_u",
			"        ldx   #" + l + "_Lines1",
			"        ldy   #" + l + "_Entries1",
			"        bsr   " + l + "_Chain",
			"        ldd   >" + l + "_u",
			"        subd  #" + planedistance,
			"        std   >" + l + "_u",
			"        ldx   #" + l + "_Lines2",
			"        ldy   #" + l + "_Entries2",
			l + "_Chain",
			"        ldb   >" + l + "_ab+1           ; the top line : an RTS at the block above it",
			"        beq   @run                     ; the picture's first : its chain's own RTS",
			"        decb",
			"        clra",
			"        lslb",
			"        rola",
			"        ldx   d,x",
			"        lda   ,x",
			"        sta   >" + l + "_saved",
			"        lda   #$39",
			"        sta   ,x",
			"        stx   >" + l + "_at",
			"        bsr   @run",
			"        lda   >" + l + "_saved",
			"        sta   [" + l + "_at]",
			"        rts",
			"@run    ldb   >" + l + "_ab",
			"        clra",
			"        lslb",
			"        rola",
			"        ldu   >" + l + "_u",
			"        jmp   [d,y]",
			l + "_ab    fdb   0",
			l + "_u     fdb   0",
			l + "_at    fdb   0",
			l + "_saved fcb   0",
		};
		for (String c : code) {
			s.append(c).append(nl);
		}
		return 31 + 33 + 11 + 7;              // the code and its variables, counted by hand
	}
}
