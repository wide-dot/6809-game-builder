package com.widedot.toolbox.graphics.gfxcomp.transformer.pairs;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.awt.image.BufferedImage;
import java.awt.image.IndexColorModel;
import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import com.widedot.toolbox.graphics.gfxcomp.Image;
import com.widedot.toolbox.graphics.gfxcomp.setting.VideoMemory;
import com.widedot.toolbox.graphics.gfxcomp.setting.VideoMode;
import com.widedot.toolbox.graphics.gfxcomp.transformer.mirror.Mirror;

/**
 * bm4s, the draw encoder : a half transparent pair (one pixel opaque, the
 * other not) is laid with a mask, its byte read, its opaque pixels' bits
 * replaced, written back, once for the byte's four pixels. The proof runs the
 * code : a small interpreter of what the encoder emits draws a picture over a
 * random background, and every pixel is checked, opaque ones in their colour,
 * transparent ones untouched, no byte written twice.
 */
public class HalfPairsTest {

	@BeforeEach
	void bm4sGeometry() {
		VideoMemory.memoryLinearBits = 4;
		VideoMemory.memoryPlanarBits = 8;
		VideoMemory.memoryLineBytes = 40;
		VideoMemory.memoryNbPlanes = 2;
		VideoMemory.memoryPlaneDistance = 8192;
		VideoMemory.videoMode = VideoMode.BM4S;
		// the code under test, not a previous run's : the cache keys on the
		// pictures, not on the encoder
		System.setProperty("builder.cache", "off");
	}

	@AfterEach
	void backToBm16() {
		VideoMemory.videoMode = VideoMode.BM16;
		System.clearProperty("builder.cache");
	}

	private static BufferedImage picture(int[][] rows) {
		byte[] r = new byte[17];
		byte[] g = new byte[17];
		byte[] b = new byte[17];
		for (int i = 1; i < 17; i++) {
			r[i] = (byte) (i * 15);
			g[i] = (byte) (i * 7);
			b[i] = (byte) (i * 3);
		}
		IndexColorModel cm = new IndexColorModel(8, 17, r, g, b, 0);
		BufferedImage img = new BufferedImage(rows[0].length, rows.length, BufferedImage.TYPE_BYTE_INDEXED, cm);
		for (int y = 0; y < rows.length; y++) {
			for (int x = 0; x < rows[y].length; x++) {
				img.getRaster().setSample(x, y, 0, rows[y][x]);
			}
		}
		return img;
	}

	/** the encoded image and its code, in a directory of its own */
	private static Object[] compile(Path dir, int[][] rows, String encoder, int shift, String position) throws Exception {
		Files.createDirectories(dir);
		File png = dir.resolve("pat.png").toFile();
		ImageIO.write(picture(rows), "png", png);
		Image image = new Image("pat", 0, png.getAbsolutePath(), encoder, Mirror.NONE, shift, position);
		image.encode(dir.toString());
		StringBuilder code = new StringBuilder();
		try (java.util.stream.Stream<Path> files = Files.list(dir)) {
			for (Path f : (Iterable<Path>) files.filter(p -> p.toString().endsWith(".asm")).sorted()::iterator) {
				code.append(Files.readString(f));
			}
		}
		return new Object[] {image, code.toString()};
	}

	// --- a 6809 interpreter for what the draw encoder emits

	private static final int PLANE0 = 0x2000;
	private static final int PLANE1 = 0x8000;

	/** runs the routine with U on plane 0's anchor ; every write counted per address */
	private static final class Cpu {
		final int[] mem = new int[0x10000];
		final int[] writes = new int[0x10000];
		int a, b, x, y, u;
		int loc1;

		int d() {
			return a << 8 | b;
		}

		void d(int v) {
			a = v >> 8 & 0xff;
			b = v & 0xff;
		}

		void st8(int at, int v) {
			mem[at & 0xffff] = v & 0xff;
			writes[at & 0xffff]++;
		}

		void st16(int at, int v) {
			st8(at, v >> 8);
			st8(at + 1, v);
		}

		int ld16(int at) {
			return mem[at & 0xffff] << 8 | mem[at + 1 & 0xffff];
		}

		static final Pattern INDEXED = Pattern.compile("^(-?\\d*),U$");

		int ea(String operand) {
			Matcher m = INDEXED.matcher(operand);
			if (!m.matches()) {
				throw new IllegalStateException("operand " + operand);
			}
			return u + (m.group(1).isEmpty() ? 0 : Integer.parseInt(m.group(1))) & 0xffff;
		}

		int value(String operand, boolean wide) {
			if (operand.startsWith("#")) {
				String n = operand.substring(1);
				return n.startsWith("$") ? Integer.parseInt(n.substring(1), 16) : Integer.decode(n);
			}
			int at = ea(operand);
			return wide ? ld16(at) : mem[at];
		}

		void run(String code) {
			for (String raw : code.split("\n")) {
				String line = raw.trim();
				if (line.isEmpty() || raw.startsWith("adr_") || line.startsWith("INCLUDE") || line.startsWith("OPT")) {
					continue;
				}
				String[] p = line.split("\\s+", 2);
				String op = p[0].toUpperCase();
				String arg = p.length > 1 ? p[1].trim() : "";
				switch (op) {
				case "LDA": a = value(arg, false); break;
				case "LDB": b = value(arg, false); break;
				case "LDD": d(value(arg, true)); break;
				case "LDX": x = value(arg, true); break;
				case "LDY": y = value(arg, true); break;
				case "LDU":
					if (!arg.equals("<glb_screen_location_1")) {
						throw new IllegalStateException(line);
					}
					u = loc1;
					break;
				case "ANDA": a &= value(arg, false); break;
				case "ANDB": b &= value(arg, false); break;
				case "ORA": a |= value(arg, false); break;
				case "ORB": b |= value(arg, false); break;
				case "ADDD": d(d() + value(arg, true) & 0xffff); break;
				case "STA": st8(ea(arg), a); break;
				case "STB": st8(ea(arg), b); break;
				case "STD": st16(ea(arg), d()); break;
				case "STX": st16(ea(arg), x); break;
				case "STY": st16(ea(arg), y); break;
				case "LEAU": u = ea(arg); break;
				case "PSHU":
					// pushed from the last of the PUL order down : S U Y X DP B A CC
					String[] regs = arg.split(",");
					List<String> order = List.of("CC", "A", "B", "DP", "X", "Y", "S", "U", "D");
					List<String> pushed = new ArrayList<String>();
					for (String r : regs) {
						pushed.add(r.trim().toUpperCase());
					}
					String[] down = {"Y", "X", "B", "A"};
					for (String r : down) {
						boolean in = pushed.contains(r) || (pushed.contains("D") && (r.equals("A") || r.equals("B")));
						if (!in) {
							continue;
						}
						switch (r) {
						case "Y": u -= 2; st16(u, y); break;
						case "X": u -= 2; st16(u, x); break;
						case "B": u -= 1; st8(u, b); break;
						default: u -= 1; st8(u, a); break;
						}
					}
					for (String r : pushed) {
						if (!order.contains(r) || r.equals("CC") || r.equals("DP") || r.equals("S") || r.equals("U")) {
							throw new IllegalStateException(line);
						}
					}
					break;
				case "RTS": return;
				default: throw new IllegalStateException("not interpreted : " + line);
				}
			}
			throw new IllegalStateException("no RTS");
		}
	}

	/**
	 * the picture drawn over a random background, checked pixel by pixel :
	 * packed pixel x (two screen pixels) of line y is in plane (x/2)%2, nibble
	 * 80*y + 2*(x/4) + x%2 of the plane's lines, the high nibble at an even
	 * one, its left pixel in the nibble's high two bits
	 */
	private static void drawsExactly(Path dir, int[][] rows, int shift, String position, long seed) throws Exception {
		Object[] built = compile(dir, rows, Image.TYPE_DRAW, shift, position);
		Image image = (Image) built[0];
		String code = (String) built[1];
		Cpu cpu = new Cpu();
		Random rnd = new Random(seed);
		int[] background = new int[0x10000];
		for (int i = 0; i < background.length; i++) {
			background[i] = rnd.nextInt(256);
			cpu.mem[i] = background[i];
		}
		int coordinate = image.getCoordinate();
		cpu.u = PLANE0 + coordinate;
		cpu.loc1 = PLANE1 + coordinate;
		cpu.run(code);
		int height = rows.length;
		int width = rows[0].length;
		int[] expected = background.clone();
		for (int y = 0; y < height; y++) {
			for (int sx = 0; sx < width; sx++) {
				int c = rows[y][sx];
				if (c == 0) {
					continue;
				}
				int x = sx / 2 + shift;                       // the packed pixel
				int nibble = 80 * y + 2 * (x / 4) + x % 2;
				int at = ((x / 2) % 2 == 0 ? PLANE0 : PLANE1) + nibble / 2;
				int bits = (nibble % 2 == 0 ? 4 : 0) + (sx % 2 == 0 ? 2 : 0);
				expected[at] = expected[at] & ~(3 << bits) | (c - 1) << bits;
			}
		}
		for (int i = 0; i < expected.length; i++) {
			assertEquals(expected[i], cpu.mem[i], String.format("byte $%04X, shift %d, %s\n%s", i, shift, position, code));
			assertTrue(cpu.writes[i] <= 1, String.format("byte $%04X written %d times\n%s", i, cpu.writes[i], code));
		}
	}

	private static int[][] random(Random rnd, int w, int h, int transparentPercent) {
		int[][] rows = new int[h][w];
		for (int y = 0; y < h; y++) {
			for (int x = 0; x < w; x++) {
				rows[y][x] = rnd.nextInt(100) < transparentPercent ? 0 : 1 + rnd.nextInt(4);
			}
		}
		return rows;
	}

	@Test
	void packAcceptsAHalfPairWhenAskedAndHalvesNamesItsOpaquePixel() throws Exception {
		// pairs : (0,2) right opaque colour 1, (3,0) left opaque colour 2, (4,4) whole
		BufferedImage src = picture(new int[][] {{0, 2, 3, 0, 4, 4}});
		BufferedImage packed = PixelPairs.pack(src, "t.png", true);
		BufferedImage halves = PixelPairs.halves(src);
		int[] p = new int[3];
		int[] h = new int[3];
		for (int x = 0; x < 3; x++) {
			p[x] = packed.getRaster().getSample(x, 0, 0);
			h[x] = halves.getRaster().getSample(x, 0, 0);
		}
		assertArrayEquals(new int[] {0, 0, 16}, p);     // the half pairs transparent, (4,4) colour 15
		assertArrayEquals(new int[] {2 + 4, 3, 0}, h);  // right pixel : index + 4 ; left : index
		assertThrows(Exception.class, () -> PixelPairs.pack(src, "t.png"));   // the default refuses
	}

	@Test
	void aByteIsLaidOnceForItsFourPixels(@TempDir Path dir) throws Exception {
		// one line, top-left : pairs 0-1 are plane 0's byte 0, pairs 2-3 plane 1's.
		// pair 0 = (0, 2) : right pixel colour 1, bits 5-4 ; pair 1 = (3, 3) whole,
		// colour 2 2 : bits 3-0 = $A ; one write : AND $C0, OR $1A
		// pair 2 = (4, 0) : left pixel colour 3, bits 7-6 : all ones, OR alone
		// pair 3 = (1, 0) : left pixel colour 0, bits 3-2 : AND $33, OR $C0 for pair 2
		int[][] rows = {{0, 2, 3, 3, 4, 0, 1, 0}};
		String code = (String) compile(dir.resolve("once"), rows, Image.TYPE_DRAW, 0, Image.POSITION_TOP_LEFT)[1];
		assertTrue(code.contains("\tLDA ,U\n\tANDA #$C0\n\tORA #$1A\n\tSTA ,U\n"), code);
		assertTrue(code.contains("\tLDA ,U\n\tANDA #$33\n\tORA #$C0\n\tSTA ,U\n"), code);
		assertFalse(code.contains("ANDA #$0F") || code.contains("ANDA #$F0"), "the whole pair written apart\n" + code);
		drawsExactly(dir.resolve("once-run"), rows, 0, Image.POSITION_TOP_LEFT, 1);
	}

	@Test
	void theWalkKeepsOffsetsShortAndFoldsIntoTheFirstLeau(@TempDir Path dir) throws Exception {
		// a left edge half pair on every line of a tall picture : 40 bytes apart
		int[][] rows = new int[40][8];
		for (int y = 0; y < rows.length; y++) {
			rows[y] = new int[] {0, 2, 3, 3, 3, 3, 3, 3};
		}
		String code = (String) compile(dir.resolve("walk"), rows, Image.TYPE_DRAW, 0, Image.POSITION_TOP_LEFT)[1];
		Matcher m = Pattern.compile("(LD|ST)[AD] (-?\\d+),U").matcher(code);
		while (m.find()) {
			int offset = Integer.parseInt(m.group(2));
			assertTrue(offset >= -128 && offset <= 127, "a 16 bit offset : " + m.group() + "\n" + code);
		}
		drawsExactly(dir.resolve("walk-run"), rows, 0, Image.POSITION_TOP_LEFT, 2);
	}

	@Test
	void randomPicturesDrawExactly(@TempDir Path dir) throws Exception {
		Random rnd = new Random(42);
		int n = 0;
		for (int round = 0; round < 12; round++) {
			int w = 2 * (1 + rnd.nextInt(16));
			int h = 1 + rnd.nextInt(24);
			int[][] rows = random(rnd, w, h, new int[] {20, 50, 80}[round % 3]);
			for (int shift = 0; shift < 2; shift++) {
				for (String position : new String[] {Image.POSITION_TOP_LEFT, Image.POSITION_CENTER}) {
					drawsExactly(dir.resolve("r" + n++), rows, shift, position, round);
				}
			}
		}
	}

	@Test
	void aPictureWithoutHalfPairsCompilesAsBefore(@TempDir Path dir) throws Exception {
		int[][] rows = {{1, 2, 0, 0, 3, 4, 4, 4}, {2, 2, 3, 3, 0, 0, 1, 1}};
		String code = (String) compile(dir.resolve("none"), rows, Image.TYPE_DRAW, 0, Image.POSITION_CENTER)[1];
		Matcher m = Pattern.compile("AND[AB] #\\$([0-9A-Fa-f]{2})").matcher(code);
		while (m.find()) {
			assertTrue(m.group(1).equalsIgnoreCase("0F") || m.group(1).equalsIgnoreCase("F0"),
					"no half pair, no pixel mask : " + m.group() + "\n" + code);
		}
		drawsExactly(dir.resolve("none-run"), rows, 0, Image.POSITION_CENTER, 3);
	}

	@Test
	void theOtherEncodersStillRefuseIt(@TempDir Path dir) {
		Exception e = assertThrows(Exception.class,
				() -> compile(dir.resolve("bdraw"), new int[][] {{2, 2, 0, 3}}, Image.TYPE_BDRAW, 0, Image.POSITION_CENTER));
		assertTrue(e.getMessage().contains("half transparent"), e.getMessage());
	}

	/** keeps the interpreter honest : a wrong expectation is caught */
	@Test
	void theCheckSeesAWrongPixel(@TempDir Path dir) throws Exception {
		int[][] rows = {{0, 2, 3, 3, 4, 0, 1, 0}};
		Object[] built = compile(dir.resolve("control"), rows, Image.TYPE_DRAW, 0, Image.POSITION_TOP_LEFT);
		Cpu cpu = new Cpu();
		cpu.u = PLANE0;
		cpu.loc1 = PLANE1;
		cpu.run((String) built[1]);
		Map<Integer, Integer> written = new HashMap<Integer, Integer>();
		for (int i = 0; i < cpu.writes.length; i++) {
			if (cpu.writes[i] > 0) {
				written.put(i, cpu.mem[i]);
			}
		}
		// plane 0 byte 0 : pair 0 right pixel colour 1 (bits 5-4 = 01), pair 1 colour 2 2 ; the left one untouched (0)
		assertEquals(Map.of(PLANE0, 0x1A, PLANE1, 0xC0), written);
	}
}
