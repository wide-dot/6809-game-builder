package com.widedot.toolbox.graphics.backlines;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.awt.image.BufferedImage;
import java.awt.image.IndexColorModel;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

import org.junit.jupiter.api.Test;

/**
 * The generated chains run by a small interpreter of the instructions they
 * use : from every line's entry, stopped above every line, both planes, the
 * screen bytes compared with the picture's.
 */
class BackLinesTest {

	static final int LINEBYTES = 40, PLANES = 0x2000;

	static BufferedImage picture(int w, int h, long seed, int colours) {
		byte[] c = new byte[17];
		IndexColorModel cm = new IndexColorModel(8, 17, c, c, c);
		BufferedImage im = new BufferedImage(w, h, BufferedImage.TYPE_BYTE_INDEXED, cm);
		Random r = new Random(seed);
		for (int y = 0; y < h; y++) {
			for (int x = 0; x < w; x++) {
				im.getRaster().setSample(x, y, 0, 1 + r.nextInt(colours));
			}
		}
		return im;
	}

	/** the generated code : instructions by line, labels to their index */
	static final class Code {
		final List<String[]> ins = new ArrayList<String[]>();
		final Map<String, Integer> labels = new HashMap<String, Integer>();

		Code(String source) {
			for (String raw : source.split("\\R")) {
				String line = raw.replaceAll(";.*", "");
				if (line.isBlank() || line.startsWith("*") || line.startsWith(" SECTION") || line.startsWith(" ENDSECTION")) {
					continue;
				}
				if (!Character.isWhitespace(line.charAt(0))) {
					String[] f = line.trim().split("\\s+");
					labels.put(f[0], ins.size());
					if (f.length == 1) {
						continue;
					}
					line = line.trim().substring(f[0].length());
				}
				String[] f = line.trim().split("\\s+", 2);
				ins.add(new String[] { f[0], f.length > 1 ? f[1].trim() : "" });
			}
		}
	}

	/** runs from a label until an RTS, or the stop label ; U given */
	static void run(Code code, String from, String stop, int u, byte[] mem) {
		int a = 0, b = 0, dp = 0, x = 0, y = 0;
		int pc = code.labels.get(from);
		Integer end = stop == null ? null : code.labels.get(stop);
		for (int guard = 0; guard < 1_000_000; guard++) {
			if (end != null && pc == end) {
				return;
			}
			String[] in = code.ins.get(pc++);
			String op = in[0], arg = in[1];
			switch (op) {
			case "lda": a = Integer.parseInt(arg.substring(2), 16); break;
			case "ldb": b = Integer.parseInt(arg.substring(2), 16); break;
			case "ldd": { int v = Integer.parseInt(arg.substring(2), 16); a = v >> 8; b = v & 0xFF; break; }
			case "ldx": x = Integer.parseInt(arg.substring(2), 16); break;
			case "ldy": y = Integer.parseInt(arg.substring(2), 16); break;
			case "tfr": dp = arg.startsWith("a") ? a : b; break;
			case "leau": u += Integer.parseInt(arg.substring(0, arg.indexOf(','))); break;
			case "jmp": pc = code.labels.get(arg); break;
			case "rts": return;
			case "pshu": {
				// PSHU's order : Y, X, DP, B, A (A ends at the lowest address)
				List<String> regs = List.of(arg.split(","));
				if (regs.contains("y")) { mem[--u & 0xFFFF] = (byte) y; mem[--u & 0xFFFF] = (byte) (y >> 8); }
				if (regs.contains("x")) { mem[--u & 0xFFFF] = (byte) x; mem[--u & 0xFFFF] = (byte) (x >> 8); }
				if (regs.contains("dp")) { mem[--u & 0xFFFF] = (byte) dp; }
				if (regs.contains("d") || regs.contains("b")) { mem[--u & 0xFFFF] = (byte) b; }
				if (regs.contains("d") || regs.contains("a")) { mem[--u & 0xFFFF] = (byte) a; }
				break;
			}
			default: throw new IllegalStateException("not interpreted : " + op + " " + arg);
			}
		}
		throw new IllegalStateException("no RTS");
	}

	static int byteOf(BufferedImage im, int plane, int k, int y) {
		int x = 4 * k + 2 * plane;
		return (im.getRaster().getSample(x, y, 0) - 1) << 4 | (im.getRaster().getSample(x + 1, y, 0) - 1);
	}

	static void check(BufferedImage im, boolean halfline, int colours) throws Exception {
		BackLines.Result r = BackLines.compile(im, "Bg", halfline, LINEBYTES, PLANES, 30);
		Code code = new Code(r.source);
		int step = halfline ? 2 : 1, n = r.lines, bytes = r.bytes;
		for (int bottom = 0; bottom < n; bottom++) {
			for (int top = 0; top <= bottom; top++) {
				byte[] mem = new byte[0x10000];
				int screen = 0xC000 + 150 * LINEBYTES + 30;  // the bottom line's first plane, its right end
				for (int c = 0; c < 2; c++) {
					run(code, "Bg_E" + (c + 1) + "_" + bottom, top > 0 ? "Bg_" + (c + 1) + "_" + (top - 1) : null,
							screen - c * PLANES, mem);
				}
				int written = 0;
				for (int v : mem) {
					written += v != 0 ? 1 : 0;
				}
				int expect = 0;
				for (int i = top; i <= bottom; i++) {
					int end = screen - (bottom - i) * LINEBYTES * step;
					for (int c = 0; c < 2; c++) {
						for (int k = 0; k < bytes; k++) {
							int want = byteOf(im, c, k, i * step);
							int at = end - c * PLANES - bytes + k;
							assertEquals(want, mem[at] & 0xFF, "line " + i + " plane " + (c + 1) + " byte " + k
									+ " (bottom " + bottom + ", top " + top + ")");
							expect += want != 0 ? 1 : 0;
						}
					}
				}
				assertEquals(expect, written, "bytes written outside the lines (bottom " + bottom + ", top " + top + ")");
			}
		}
	}

	@Test
	void drawsEveryLineSpanHalfline() throws Exception {
		check(picture(16, 20, 1, 16), true, 16);
	}

	@Test
	void drawsEveryLineSpanFullLine() throws Exception {
		check(picture(8, 9, 2, 16), false, 16);
	}

	@Test
	void keepsValuesAcrossLines() throws Exception {
		// few colours : values repeat, the search keeps them in the registers
		check(picture(136, 24, 3, 2), true, 2);
		BackLines.Result plain = BackLines.compile(picture(136, 24, 4, 1), "Bg", true, LINEBYTES, PLANES, 30);
		BackLines.Result busy = BackLines.compile(picture(136, 24, 5, 16), "Bg", true, LINEBYTES, PLANES, 30);
		assertTrue(plain.size < busy.size / 2, plain.size + " against " + busy.size);
	}

	@Test
	void refusesATransparentPixel() {
		BufferedImage im = picture(8, 4, 6, 16);
		im.getRaster().setSample(3, 2, 0, 0);
		Exception e = assertThrows(Exception.class, () -> BackLines.compile(im, "Bg", true, LINEBYTES, PLANES, 30));
		assertTrue(e.getMessage().contains("(3,2)"), e.getMessage());
	}

	@Test
	void refusesAWidthOffTheInterleave() {
		assertThrows(Exception.class, () -> BackLines.compile(picture(10, 4, 7, 16), "Bg", true, LINEBYTES, PLANES, 30));
	}
}
