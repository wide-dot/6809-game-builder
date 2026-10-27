package com.widedot.toolbox.graphics.spritestream;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * The walkers of a shape set, as an lwasm source : the code that reads a
 * stream and draws it, one routine per record shape and box plane parity.
 *
 * The screen is the back buffer in the data window, a line 40 bytes a plane :
 * the box's first byte's plane ("plane 0") at Y, the other plane at Y + ofs,
 * ofs = -$2000 when the box starts on an even screen byte (plane 0 is the
 * RAMA half at $C000), +$2001 when odd (plane 0 is RAMB at $A000). Y steps one
 * record's delta (rows x 40 + columns) at a time.
 *
 * <ul>
 * <li>Stored facing ({@code wn}) : records [code][delta][payload] (a
 * mirrorable stream puts the mirrored delta in front, skipped). PULU D, LEAY
 * B,Y, JMP [A,X] : X is the jump table of the plane parity
 * ({@code spritestream.jtn} holds both).</li>
 * <li>Mirrored facing ({@code wm}) : [mirrored delta][code][delta][payload]
 * read with LDD ,U, LEAY A,Y, then LDA the table number and JMP [D,X] : X is
 * the middle of the 256 byte reversal table, the four jump tables (plane
 * parity x parity of the box width) 256 bytes apart after it. Each byte is
 * written right to left through the table.</li>
 * <li>save : each routine pushes on S the screen bytes it masks, then the
 * code of its restore routine and Y ; the restore walker pulls every record
 * of a buffer back, last first ({@code spritestream.restore}). S is that
 * stack while a walker runs : an interrupt pushes below it, on free space.</li>
 * </ul>
 *
 * The blocks are laid out around the reversal table : every routine ends
 * with a jump, so routines fill the gaps between the aligned jump tables.
 */
final class Walker {

	static final String PF = "spritestream";
	static final int LINE = 40;
	static final int[] OFS = { -0x2000, 0x2001 };
	final Options o;
	/** restore routine name by pushed sequence, in creation order */
	private final Map<String, String> rseq = new LinkedHashMap<String, String>();
	private final Map<String, String> pushedOf = new LinkedHashMap<String, String>();
	final List<String> rnames = new ArrayList<String>();
	private int rbias;

	/** a routine or a table : placed whole */
	static final class Block {
		final String name;
		final List<Ins> lines = new ArrayList<Ins>();

		Block(String name) {
			this.name = name;
		}

		Block add(Ins i) {
			lines.add(i);
			return this;
		}

		Block op(String op, String arg) {
			return add(Ins.op(op, arg));
		}

		Block op(String op) {
			return add(Ins.op(op));
		}

		Block label(String l) {
			return add(Ins.label(l));
		}

		Block addAll(List<Ins> l) {
			lines.addAll(l);
			return this;
		}

		int size() {
			int s = 0;
			for (Ins i : lines) {
				s += i.size;
			}
			return s;
		}

		int cycles() {
			int c = 0;
			for (Ins i : lines) {
				c += i.cycles;
			}
			return c;
		}
	}

	/** a body : its lines and what it pushed ({bytes, offset from Y}), in push order */
	static final class Body {
		final List<Ins> lines = new ArrayList<Ins>();
		final List<int[]> pushed = new ArrayList<int[]>();
	}

	Walker(Options o) {
		this.o = o;
		if (!o.save) {
			return;
		}
		// the restore routines : one per distinct pull sequence (a stored and a
		// mirrored routine that push the same bytes share theirs)
		for (int kp = 0; kp < 2; kp++) {
			for (Shape s : o.shapes) {
				pushedOf.put("n" + s.name() + "_" + kp, key(bodyN(s, kp, 0).pushed));
				if (o.mirrorable) {
					pushedOf.put("m" + s.name() + "_" + kp, key(bodyM(s, kp, 0).pushed));
				}
			}
		}
		for (String k : pushedOf.values()) {
			if (!rseq.containsKey(k)) {
				rseq.put(k, "r" + rseq.size());
			}
		}
		rnames.add("end");
		rnames.addAll(rseq.values());
		if (2 * rnames.size() > 256) {
			throw new IllegalStateException(rnames.size() + " restore routines, past the 128 the restore walker"
					+ " indexes : fewer multi-row records or a shorter segment");
		}
		rbias = 2 * rnames.size() <= 128 ? 0 : 128;
	}

	private static String key(List<int[]> pushed) {
		StringBuilder sb = new StringBuilder();
		for (int[] p : pushed) {
			sb.append(p[0]).append(':').append(p[1]).append(' ');
		}
		return sb.toString();
	}

	/** the restore code of a pull sequence name (r3, end) */
	int rcode(String rname) {
		return 2 * rnames.indexOf(rname) - rbias;
	}

	private int rcodeOf(String routine) {
		return rcode(rseq.get(pushedOf.get(routine)));
	}

	static String ix(int off, String reg) {
		return off == 0 ? "," + reg : off + "," + reg;
	}

	/** offset from Y of the stored byte i of a segment whose first byte is on plane p */
	static int whereN(int p, int i, int ofs) {
		int r = p + i;
		return (r >> 1) + (r % 2 != 0 ? ofs : 0);
	}

	/** offset from Y of byte i written leftwards from the mirrored first byte on plane pm */
	static int whereM(int pm, int i, int ofs) {
		int r = pm - i;
		return (r >> 1) + (r % 2 != 0 ? ofs : 0);
	}

	// ---------------------------------------------------------------- bodies

	/** stored facing : plane 0 at Y, plane 1 at Y + ofs */
	Body bodyN(Shape s, int kp, int rc) {
		int ofs = OFS[kp];
		int[][] offs = Shape.offsets(s.n, s.opaque);
		int size = s.rowBytes();
		Body b = new Body();
		List<Ins> L = b.lines;
		for (int t = 0; t < s.rows; t++) {
			int base = t * size;
			for (int[] g : Shape.groups(s.n)) {
				int a = whereN(s.p, g[0], ofs) + LINE * t;
				int mo = offs[g[0]][0] + base, d = offs[g[0]][1] + base;
				boolean pair = g.length == 2;
				if (s.opaque) {
					if (pair) {
						if (o.save) {
							L.add(Ins.op("ldd", ix(a, "y")));
							L.add(Ins.op("pshs", "d"));
						}
						L.add(Ins.op("ldd", ix(d, "u")));
						L.add(Ins.op("std", ix(a, "y")));
					} else {
						if (o.save) {
							L.add(Ins.op("lda", ix(a, "y")));
							L.add(Ins.op("pshs", "a"));
						}
						L.add(Ins.op("lda", ix(d, "u")));
						L.add(Ins.op("sta", ix(a, "y")));
					}
				} else if (pair) {
					L.add(Ins.op("ldd", ix(a, "y")));
					if (o.save) {
						L.add(Ins.op("pshs", "d"));
					}
					L.add(Ins.op("anda", ix(mo, "u")));
					L.add(Ins.op("andb", ix(mo + 1, "u")));
					L.add(Ins.op("addd", ix(d, "u")));
					L.add(Ins.op("std", ix(a, "y")));
				} else {
					L.add(Ins.op("lda", ix(a, "y")));
					if (o.save) {
						L.add(Ins.op("pshs", "a"));
					}
					L.add(Ins.op("anda", ix(mo, "u")));
					L.add(Ins.op("adda", ix(d, "u")));
					L.add(Ins.op("sta", ix(a, "y")));
				}
				if (o.save) {
					b.pushed.add(new int[] { pair ? 2 : 1, a });
				}
			}
		}
		if (o.save) {
			L.add(Ins.op("ldb", "#" + rc));
			L.add(Ins.op("pshs", "y,b"));
		}
		if (s.rows > 1 && s.advances()) {
			L.add(Ins.op("leay", ix(LINE * (s.rows - 1), "y")));
		}
		L.add(Ins.op("leau", ix(s.rows * size + (o.mirrorable ? 1 : 0), "u")));
		return b;
	}

	/** mirrored facing : X the reversal table, plane 1 at Y + ofs, byte i at mirrored position pm - i */
	Body bodyM(Shape s, int kp, int rc) {
		int ofs = OFS[kp];
		int pm = s.p;
		int[][] offs = Shape.offsets(s.n, s.opaque);
		int size = s.rowBytes();
		Body b = new Body();
		List<Ins> L = b.lines;
		for (int t = 0; t < s.rows; t++) {
			int base = t * size;
			for (int[] g : Shape.groups(s.n)) {
				if (g.length == 2) {
					int i0 = g[0], i2 = g[1];
					int a2 = whereM(pm, i2, ofs) + LINE * t;
					int a0 = whereM(pm, i0, ofs) + LINE * t;
					if (s.opaque) {
						// i0 -> column c, i2 -> column c - 1 : both through the table, one STD
						if (o.save) {
							L.add(Ins.op("ldd", ix(a2, "y")));
							L.add(Ins.op("pshs", "d"));
							b.pushed.add(new int[] { 2, a2 });
						}
						L.add(Ins.op("ldb", ix(offs[i2][1] + base, "u")));
						L.add(Ins.op("lda", "b,x"));
						L.add(Ins.op("ldb", ix(offs[i0][1] + base, "u")));
						L.add(Ins.op("ldb", "b,x"));
						L.add(Ins.op("std", ix(a2, "y")));
						continue;
					}
					if (o.save) {
						// one LDD, one push for both : byte i2 then i0
						L.add(Ins.op("ldd", ix(a2, "y")));
						L.add(Ins.op("pshs", "d"));
						b.pushed.add(new int[] { 2, a2 });
						maskedM(L, offs[i2], base, a2);
						L.add(Ins.op("lda", ix(a0, "y")));
						maskedM(L, offs[i0], base, a0);
					} else {
						L.add(Ins.op("lda", ix(a2, "y")));
						maskedM(L, offs[i2], base, a2);
						L.add(Ins.op("lda", ix(a0, "y")));
						maskedM(L, offs[i0], base, a0);
					}
				} else {
					int i = g[0];
					int a = whereM(pm, i, ofs) + LINE * t;
					if (s.opaque) {
						if (o.save) {
							L.add(Ins.op("lda", ix(a, "y")));
							L.add(Ins.op("pshs", "a"));
							b.pushed.add(new int[] { 1, a });
						}
						L.add(Ins.op("ldb", ix(offs[i][1] + base, "u")));
						L.add(Ins.op("lda", "b,x"));
						L.add(Ins.op("sta", ix(a, "y")));
						continue;
					}
					L.add(Ins.op("lda", ix(a, "y")));
					if (o.save) {
						L.add(Ins.op("pshs", "a"));
						b.pushed.add(new int[] { 1, a });
					}
					maskedM(L, offs[i], base, a);
				}
			}
		}
		if (o.save) {
			L.add(Ins.op("ldb", "#" + rc));
			L.add(Ins.op("pshs", "y,b"));
		}
		if (s.rows > 1 && s.advances()) {
			L.add(Ins.op("leay", ix(LINE * (s.rows - 1), "y")));
		}
		L.add(Ins.op("leau", ix(s.rows * size, "u")));
		return b;
	}

	/** A holds the screen byte : AND its reversed mask, OR its reversed data, store */
	private static void maskedM(List<Ins> L, int[] off, int base, int a) {
		L.add(Ins.op("ldb", ix(off[0] + base, "u")));
		L.add(Ins.op("anda", "b,x"));
		L.add(Ins.op("ldb", ix(off[1] + base, "u")));
		L.add(Ins.op("ora", "b,x"));
		L.add(Ins.op("sta", ix(a, "y")));
	}

	/** the restore's pulls, top of the stack first ; merged in one PULS when mergepulls */
	List<Ins> pulls(List<int[]> groups) {
		List<Ins> out = new ArrayList<Ins>();
		boolean m = o.mergePulls;
		int i = 0;
		while (i < groups.size()) {
			int k0 = groups.get(i)[0];
			int k1 = i + 1 < groups.size() ? groups.get(i + 1)[0] : 0;
			int k2 = i + 2 < groups.size() ? groups.get(i + 2)[0] : 0;
			String a0 = ix(groups.get(i)[1], "y");
			String a1 = i + 1 < groups.size() ? ix(groups.get(i + 1)[1], "y") : null;
			String a2 = i + 2 < groups.size() ? ix(groups.get(i + 2)[1], "y") : null;
			if (m && k0 == 1 && k1 == 1 && k2 == 2) {
				out.add(Ins.op("puls", "a,b,u"));
				out.add(Ins.op("sta", a0));
				out.add(Ins.op("stb", a1));
				out.add(Ins.op("stu", a2));
				i += 3;
			} else if (m && k0 == 2 && k1 == 2) {
				out.add(Ins.op("puls", "d,u"));
				out.add(Ins.op("std", a0));
				out.add(Ins.op("stu", a1));
				i += 2;
			} else if (m && k0 == 1 && k1 == 2) {
				out.add(Ins.op("puls", "a,u"));
				out.add(Ins.op("sta", a0));
				out.add(Ins.op("stu", a1));
				i += 2;
			} else if (m && k0 == 1 && k1 == 1) {
				out.add(Ins.op("puls", "a,b"));
				out.add(Ins.op("sta", a0));
				out.add(Ins.op("stb", a1));
				i += 2;
			} else if (k0 == 2) {
				out.add(Ins.op("puls", "d"));
				out.add(Ins.op("std", a0));
				i += 1;
			} else {
				out.add(Ins.op("puls", "a"));
				out.add(Ins.op("sta", a0));
				i += 1;
			}
		}
		return out;
	}

	// ---------------------------------------------------------------- walkers

	List<Ins> dispatchN() {
		List<Ins> d = new ArrayList<Ins>();
		d.add(Ins.op("pulu", "d"));
		d.add(Ins.op("leay", "b,y"));
		d.add(Ins.op("jmp", "[a,x]"));
		return d;
	}

	List<Ins> dispatchM() {
		List<Ins> d = new ArrayList<Ins>();
		d.add(Ins.op("ldd", ",u"));
		d.add(Ins.op("leay", "a,y"));
		d.add(Ins.op("lda", "<" + PF + ".jtk"));
		d.add(Ins.op("leau", "3,u"));
		d.add(Ins.op("jmp", "[d,x]"));
		return d;
	}

	/** the routine of a shape, stored facing, with its dispatch */
	Block routineN(Shape s, int kp) {
		Block b = new Block(PF + ".wn." + s.name() + "_" + kp);
		b.label(b.name);
		b.addAll(bodyN(s, kp, o.save ? rcodeOf("n" + s.name() + "_" + kp) : 0).lines);
		return b.addAll(dispatchN());
	}

	/** the routine of a shape, mirrored facing, with its dispatch */
	Block routineM(Shape s, int kp) {
		Block b = new Block(PF + ".wm." + s.name() + "_" + kp);
		b.label(b.name);
		b.addAll(bodyM(s, kp, o.save ? rcodeOf("m" + s.name() + "_" + kp) : 0).lines);
		return b.addAll(dispatchM());
	}

	/** cycles of a record of shape s, its dispatch included, both walks added for a mirrorable stream */
	int cost(Shape s) {
		int c = routineN(s, 0).cycles();
		if (o.mirrorable) {
			c += routineM(s, 0).cycles();
		}
		return c;
	}

	/** the movable blocks, in their natural order */
	List<Block> blocks() {
		List<Block> out = new ArrayList<Block>();
		String saveS = "<" + PF + ".saveS", top = "<" + PF + ".top";

		// stored facing
		Block draw = new Block(PF + ".wn.draw");
		draw.label(draw.name);
		if (o.save) {
			draw.op("sts", saveS).op("lds", top);
		}
		if (o.mirrorable) {
			draw.op("leau", "1,u");
		}
		out.add(draw.addAll(dispatchN()));
		Block nop = new Block(PF + ".wn.nop");
		nop.label(nop.name);
		if (o.mirrorable) {
			nop.op("leau", "1,u");
		}
		out.add(nop.addAll(dispatchN()));
		for (int kp = 0; kp < 2; kp++) {
			for (Shape s : o.shapes) {
				out.add(routineN(s, kp));
			}
		}
		Block end = new Block(PF + ".wn.end");
		end.label(end.name);
		if (o.save) {
			end.op("sts", top).op("lds", saveS);
		}
		out.add(end.op("rts"));
		for (int kp = 0; kp < 2; kp++) {
			Block t = new Block(PF + ".jtn" + kp);
			t.label(t.name);
			for (String nm : o.names) {
				t.add(Ins.data("fdb", PF + ".wn." + nm + ("end".equals(nm) || "nop".equals(nm) ? "" : "_" + kp), 2));
			}
			out.add(t);
		}
		out.add(new Block(PF + ".jtn").label(PF + ".jtn").add(Ins.data("fdb", PF + ".jtn0," + PF + ".jtn1", 4)));

		// mirrored facing
		if (o.mirrorable) {
			Block md = new Block(PF + ".wm.draw");
			md.label(md.name);
			if (o.save) {
				md.op("sts", saveS).op("lds", top);
			}
			out.add(md.addAll(dispatchM()));
			out.add(new Block(PF + ".wm.nop").label(PF + ".wm.nop").addAll(dispatchM()));
			for (int kp = 0; kp < 2; kp++) {
				for (Shape s : o.shapes) {
					out.add(routineM(s, kp));
				}
			}
			Block me = new Block(PF + ".wm.end");
			me.label(me.name);
			if (o.save) {
				me.op("sts", top).op("lds", saveS);
			}
			out.add(me.op("rts"));
		}

		// restore
		if (o.save) {
			Block r = new Block(PF + ".restore");
			r.label(r.name).op("sts", saveS).op("lds", top).op("ldx", "#" + PF + ".wr.jt").op("puls", "b,y")
					.op("jmp", "[b,x]");
			out.add(r);
			Block re = new Block(PF + ".wr.end");
			re.label(re.name).op("leas", "-3,s").op("sts", top).op("lds", saveS).op("rts");
			out.add(re);
			Map<String, String> seqs = new LinkedHashMap<String, String>();
			for (Map.Entry<String, String> e : rseq.entrySet()) {
				seqs.put(e.getValue(), e.getKey());
			}
			for (String nm : rnames) {
				if ("end".equals(nm)) {
					continue;
				}
				Block rr = new Block(PF + ".wr." + nm);
				rr.label(rr.name);
				List<int[]> groups = parse(seqs.get(nm));
				java.util.Collections.reverse(groups);
				rr.addAll(pulls(groups));
				out.add(rr.op("puls", "b,y").op("jmp", "[b,x]"));
			}
			Block jt = new Block(PF + ".wr.jt");
			int half = rbias / 2;
			for (int i = 0; i < rnames.size(); i++) {
				if (rbias != 0 && i == 0) {
					jt.label(PF + ".wr.jt.lo");
				}
				if (i == half) {
					jt.label(PF + ".wr.jt");
				}
				jt.add(Ins.data("fdb", PF + ".wr." + rnames.get(i), 2));
			}
			out.add(jt);
		}

		return out;
	}

	private static List<int[]> parse(String key) {
		List<int[]> out = new ArrayList<int[]>();
		for (String f : key.trim().split(" ")) {
			if (f.isEmpty()) {
				continue;
			}
			String[] kv = f.split(":");
			out.add(new int[] { Integer.parseInt(kv[0]), Integer.parseInt(kv[1]) });
		}
		return out;
	}

	/** the reversal table, its middle labelled (B a signed index) */
	private static Block reversal() {
		Block b = new Block(PF + ".rev.lo");
		b.label(PF + ".rev.lo");
		for (int i = 0; i < 128; i += 16) {
			b.add(Ins.data("fcb", revs(128 + i), 16));
		}
		b.label(PF + ".rev");
		for (int i = 0; i < 128; i += 16) {
			b.add(Ins.data("fcb", revs(i), 16));
		}
		return b;
	}

	private static String revs(int from) {
		StringBuilder sb = new StringBuilder();
		for (int v = from; v < from + 16; v++) {
			sb.append(sb.length() == 0 ? "" : ",").append(String.format("$%02X", Picture.rev(v)));
		}
		return sb.toString();
	}

	/** mirrored jump table k (1 to 4 : 1 + 2 x plane parity + box width parity) */
	private Block mirroredTable(int k) {
		Block t = new Block(PF + ".jtm" + k);
		t.label(t.name);
		int kp = (k - 1) >> 1, q = (k - 1) & 1;
		for (String nm : o.names) {
			String target;
			if ("end".equals(nm) || "nop".equals(nm)) {
				target = PF + ".wm." + nm;
			} else {
				Shape s = o.shapes.get(o.names.indexOf(nm) - 2);
				target = PF + ".wm." + (q == 0 ? s : s.flip()).name() + "_" + kp;
			}
			t.add(Ins.data("fdb", target, 2));
		}
		return t;
	}

	// ---------------------------------------------------------------- source

	/** the whole source : equates, then the blocks laid out around the reversal table */
	String source() {
		StringBuilder sb = new StringBuilder();
		sb.append("* Generated by spritestream : the walkers (").append(o.describe()).append(" mergepulls=")
				.append(o.mergePulls).append(")\n");
		sb.append("* Needs the direct page equates ").append(PF).append(".saveS, .top, .jtk : the engine's spritestream.asm\n");
		eq(sb, PF + ".SEGMENT", String.valueOf(o.segment));
		eq(sb, PF + ".MIRRORABLE", o.mirrorable ? "1" : "0");
		eq(sb, PF + ".SAVE", o.save ? "1" : "0");
		eq(sb, PF + ".CODES", String.valueOf(o.names.size()));
		eq(sb, PF + ".NOP", String.valueOf(o.code("nop")));
		if (o.save) {
			eq(sb, PF + ".REND", String.valueOf(rcode("end")));
		}
		List<Block> blocks = blocks();
		List<Block> placed = new ArrayList<Block>();
		slack = 0;
		if (o.mirrorable) {
			placed.add(reversal());
			int at = 128;                                     // bytes past the reversal table's middle
			for (int k = 1; k <= 4; k++) {
				int gap = 256 * k - at;
				while (true) {
					Block best = null;
					for (Block b : blocks) {
						int s = b.size();
						if (s <= gap && (best == null || s > best.size())) {
							best = b;
						}
					}
					if (best == null) {
						break;
					}
					blocks.remove(best);
					placed.add(best);
					gap -= best.size();
					at += best.size();
				}
				Block pad = new Block("pad" + k);
				pad.add(Ins.data("ifgt", "*-(" + PF + ".rev+" + 256 * k + ")", 0));
				pad.add(Ins.data("error", "\"spritestream : the layout runs into jump table " + k + "\"", 0));
				pad.add(Ins.data("endc", "", 0));
				pad.add(Ins.data("rmb", PF + ".rev+" + 256 * k + "-*", gap));
				placed.add(pad);
				slack += gap;
				at += gap;
				Block t = mirroredTable(k);
				placed.add(t);
				at += t.size();
			}
		}
		placed.addAll(blocks);
		this.placed = placed;
		layoutSize = 0;
		for (Block b : placed) {
			layoutSize += b.size();
		}
		for (Block b : placed) {
			for (Ins i : b.lines) {
				sb.append(i.text()).append('\n');
			}
		}
		sb.append(PF).append(".walkers.end\n");
		return sb.toString();
	}

	private static void eq(StringBuilder sb, String name, String value) {
		sb.append(name).append(" equ ").append(value).append('\n');
	}

	/** the blocks in their place, set by source() */
	List<Block> placed;
	/** bytes of the laid out source (gaps included), set by source() */
	int layoutSize;
	/** bytes of the gaps left between the aligned tables, set by source() */
	int slack;
}
