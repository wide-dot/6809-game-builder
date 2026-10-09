package com.widedot.toolbox.graphics.tilemap.chunkmap;

import java.awt.image.BufferedImage;
import java.awt.image.IndexColorModel;
import java.awt.image.Raster;
import java.awt.image.WritableRaster;
import java.io.File;
import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import javax.imageio.ImageIO;

/**
 * A chunked tilemap, as the Mega Drive Sonic games lay out their levels,
 * converted to the engine's TilemapBuffer formats.
 *
 * The source is a level made of chunks of 8x8 blocks : a chunk mapping word
 * per block ({@code SSTT YXII IIII IIII} : the solidity of the two collision
 * layers, the block's flips, its index), block mappings (four 8x8 pattern
 * words a block, {@code PCCY XAAA AAAA AAAA}, read for their priority bit),
 * one collision index byte per block and layer, and act layouts (rows of 256
 * bytes, the plane's 128 chunk ids then the background's). The pictures
 * come drawn already : one image per chunk, the block flips applied, at the
 * target's resolution and in its palette, a column of chunks (chunk n at
 * y = n times the chunk's height). Drawing them is the game's adaptation of
 * its assets ; this is the engine's half.
 *
 * Out of it come :
 * <ul>
 * <li>the tileset : every cell of every chunk the acts' plane uses, cut out
 * and merged when the same — the same picture (on the even lines alone in
 * half-line : the odd ones are never drawn, and come out empty), the same
 * two collision indexes and the same flip (unless both indexes leave nothing
 * to flip : none, or the full block). Tile 0 is the empty one, numbered
 * before any other ;</li>
 * <li>the chunk entries, a big endian word each : priority (15, the block's
 * first pattern's), the solidity (11-14), the opaque bit (10, with
 * {@code opaque} : no transparent pixel on the drawn lines) and the tile
 * index (0-9, or 0-10 without the opaque bit). The chunks are merged when
 * their 64 entries are the same, renumbered in the order the acts use them,
 * chunk 0 the empty one, and split in banks of 128 ;</li>
 * <li>each act's plane on the zone's chunk ids, 128 bytes a row ;</li>
 * <li>a collision byte per tile and layer, and the flip (the bits of the
 * chunk entry) the collision reads.</li>
 * </ul>
 *
 * Blocks drawn at run time (animated : the source maps them past its block
 * mappings) are declared ; each takes the tile index past the tileset, in
 * the declared order, where the game's animated tilesets follow its index.
 */
public final class ChunkMap {

	/** Blocks a chunk holds per row and per column. */
	public static final int CELLS = 8;
	/** Chunks a bank holds. */
	public static final int BANK = 128;
	/** Chunks the engine addresses : two banks. */
	public static final int MAX_CHUNKS = 2 * BANK;

	/** An animated block : its priority and whether its frames hide what is behind. */
	public static final class Animated {
		public final boolean high;
		public final boolean opaque;

		public Animated(boolean high, boolean opaque) {
			this.high = high;
			this.opaque = opaque;
		}
	}

	/** What the conversion produces. */
	public static final class Result {
		public final BufferedImage tiles;
		public final int tileCount;
		public final List<int[]> chunks;
		public final List<byte[]> layouts;
		public final byte[] primary;
		public final byte[] secondary;
		public final byte[] flip;

		Result(BufferedImage tiles, int tileCount, List<int[]> chunks, List<byte[]> layouts,
				byte[] primary, byte[] secondary, byte[] flip) {
			this.tiles = tiles;
			this.tileCount = tileCount;
			this.chunks = chunks;
			this.layouts = layouts;
			this.primary = primary;
			this.secondary = secondary;
			this.flip = flip;
		}
	}

	private ChunkMap() {
	}

	/**
	 * @param sheet     the chunks' pictures, 8 bit indexed, colour 0 transparent
	 * @param mappings  chunk mappings, 64 big endian words a chunk
	 * @param blocks    block mappings, 4 big endian words a block
	 * @param primary   collision index of each block, normal layer
	 * @param secondary collision index of each block, alternate layer
	 * @param layouts   the acts' layouts, rows of 256 bytes (the plane's 128 first)
	 * @param halfline  the even lines alone are drawn
	 * @param opaque    entries carry the opaque bit (10) ; the index keeps bits 0-9
	 * @param animated  blocks drawn at run time, by block index, in tile order
	 */
	public static Result convert(BufferedImage sheet, byte[] mappings, byte[] blocks, byte[] primary,
			byte[] secondary, List<byte[]> layouts, boolean halfline, boolean opaque,
			LinkedHashMap<Integer, Animated> animated) throws Exception {

		if (!(sheet.getColorModel() instanceof IndexColorModel)) {
			throw new Exception("chunkmap : the chunk pictures must be an indexed PNG");
		}
		if (mappings.length % (CELLS * CELLS * 2) != 0) {
			throw new Exception("chunkmap : chunk mappings of " + mappings.length
					+ " bytes, not a whole number of 128 byte chunks");
		}
		int sourceChunks = mappings.length / (CELLS * CELLS * 2);
		if (sheet.getWidth() % CELLS != 0 || sheet.getHeight() % sourceChunks != 0
				|| (sheet.getHeight() / sourceChunks) % CELLS != 0) {
			throw new Exception("chunkmap : a " + sheet.getWidth() + "x" + sheet.getHeight()
					+ " picture does not cut into " + sourceChunks + " chunks of 8x8 cells");
		}
		int tw = sheet.getWidth() / CELLS;
		int chunkH = sheet.getHeight() / sourceChunks;
		int th = chunkH / CELLS;
		int nblocks = blocks.length / 8;
		int indexMask = opaque ? 0x3FF : 0x7FF;
		Raster src = sheet.getRaster();

		// the tiles : picture, then the collision key
		List<byte[]> pictures = new ArrayList<byte[]>();
		List<int[]> collision = new ArrayList<int[]>();
		Map<ByteBuffer, Integer> tileOf = new HashMap<ByteBuffer, Integer>();
		byte[] empty = new byte[tw * th];
		tileOf.put(tileKey(empty, 0, 0, 0, tw, th, halfline), 0);
		pictures.add(empty);
		collision.add(new int[] { 0, 0, 0 });

		List<int[]> chunks = new ArrayList<int[]>();
		Map<List<Integer>, Integer> chunkOf = new HashMap<List<Integer>, Integer>();
		chunks.add(new int[CELLS * CELLS]);
		chunkOf.put(words(chunks.get(0)), 0);
		Map<Integer, Integer> zoneChunk = new HashMap<Integer, Integer>();
		zoneChunk.put(0, 0);
		List<Integer> animatedOrder = new ArrayList<Integer>(animated.keySet());

		List<byte[]> outLayouts = new ArrayList<byte[]>();
		for (byte[] layout : layouts) {
			if (layout.length % 256 != 0) {
				throw new Exception("chunkmap : a layout of " + layout.length
						+ " bytes, not a whole number of 256 byte rows");
			}
			int rows = layout.length / 256;
			byte[] out = new byte[rows * 128];
			for (int y = 0; y < rows; y++) {
				for (int x = 0; x < 128; x++) {
					int c = layout[y * 256 + x] & 0xFF;
					if (c >= sourceChunks) {
						throw new Exception("chunkmap : the layout uses chunk " + c + ", the mappings hold "
								+ sourceChunks);
					}
					Integer z = zoneChunk.get(c);
					if (z == null) {
						int[] entries = new int[CELLS * CELLS];
						for (int i = 0; i < CELLS * CELLS; i++) {
							int o = (c * CELLS * CELLS + i) * 2;
							int w = (mappings[o] & 0xFF) << 8 | (mappings[o + 1] & 0xFF);
							int b = w & 0x3FF;
							int f = (w >> 10) & 3;
							int solidity = (w >> 12) & 0xF;
							int word;
							if (animated.containsKey(b)) {
								Animated a = animated.get(b);
								// patched past the tileset once its size is known
								word = (a.high ? 0x8000 : 0) | solidity << 11 | (opaque && a.opaque ? 0x400 : 0)
										| (0x10000 + animatedOrder.indexOf(b));
							} else {
								if (b >= nblocks) {
									throw new Exception("chunkmap : chunk " + c + " uses block " + b
											+ ", past the " + nblocks + " block mappings, and it is not declared animated");
								}
								byte[] pic = cut(src, tw, th, c * chunkH + (i / CELLS) * th, (i % CELLS) * tw, halfline);
								int p = b < primary.length ? primary[b] & 0xFF : 0;
								int s = b < secondary.length ? secondary[b] & 0xFF : 0;
								int ff = (p == 0 || p == 0xFF) && (s == 0 || s == 0xFF) ? 0 : f;
								ByteBuffer key = tileKey(pic, p, s, ff, tw, th, halfline);
								Integer t = tileOf.get(key);
								if (t == null) {
									t = pictures.size();
									tileOf.put(key, t);
									pictures.add(pic);
									collision.add(new int[] { p, s, ff });
								}
								boolean high = (blocks[b * 8] & 0x80) != 0;
								boolean full = t != 0 && covers(pic, tw, th, halfline);
								word = (high ? 0x8000 : 0) | solidity << 11 | (opaque && full ? 0x400 : 0) | t;
							}
							entries[i] = word;
						}
						List<Integer> k = words(entries);
						z = chunkOf.get(k);
						if (z == null) {
							z = chunks.size();
							chunkOf.put(k, z);
							chunks.add(entries);
						}
						zoneChunk.put(c, z);
					}
					out[y * 128 + x] = (byte) (int) z;
				}
			}
			outLayouts.add(out);
		}

		int count = pictures.size();
		if (chunks.size() > MAX_CHUNKS) {
			throw new Exception("chunkmap : " + chunks.size() + " chunks, the engine's two banks hold "
					+ MAX_CHUNKS);
		}
		if (count + animated.size() - 1 > indexMask) {
			throw new Exception("chunkmap : " + count + " tiles and " + animated.size()
					+ " animated, past the entries' index (" + (indexMask + 1) + (opaque ? ", the opaque bit taking bit 10)" : ")"));
		}
		for (int[] entries : chunks) {
			for (int i = 0; i < entries.length; i++) {
				if ((entries[i] & 0x10000) != 0) {
					entries[i] = (entries[i] & 0xFC00) | (count + (entries[i] & 0xFFFF));
				}
			}
		}

		IndexColorModel cm = (IndexColorModel) sheet.getColorModel();
		BufferedImage tiles = new BufferedImage(tw, th * count, BufferedImage.TYPE_BYTE_INDEXED, cm);
		WritableRaster dst = tiles.getRaster();
		byte[] primaryOut = new byte[count];
		byte[] secondaryOut = new byte[count];
		byte[] flipOut = new byte[count];
		for (int t = 0; t < count; t++) {
			byte[] pic = pictures.get(t);
			for (int y = 0; y < th; y++) {
				for (int x = 0; x < tw; x++) {
					dst.setSample(x, t * th + y, 0, pic[y * tw + x] & 0xFF);
				}
			}
			primaryOut[t] = (byte) collision.get(t)[0];
			secondaryOut[t] = (byte) collision.get(t)[1];
			flipOut[t] = (byte) collision.get(t)[2];
		}
		return new Result(tiles, count, chunks, outLayouts, primaryOut, secondaryOut, flipOut);
	}

	/** One cell's picture ; in half-line the odd lines are emptied (never drawn). */
	private static byte[] cut(Raster src, int tw, int th, int top, int left, boolean halfline) {
		byte[] pic = new byte[tw * th];
		for (int y = 0; y < th; y++) {
			if (halfline && (y & 1) != 0) {
				continue;
			}
			for (int x = 0; x < tw; x++) {
				pic[y * tw + x] = (byte) src.getSample(left + x, top + y, 0);
			}
		}
		return pic;
	}

	/** No transparent pixel on the drawn lines. */
	private static boolean covers(byte[] pic, int tw, int th, boolean halfline) {
		for (int y = 0; y < th; y += halfline ? 2 : 1) {
			for (int x = 0; x < tw; x++) {
				if (pic[y * tw + x] == 0) {
					return false;
				}
			}
		}
		return true;
	}

	private static ByteBuffer tileKey(byte[] pic, int p, int s, int f, int tw, int th, boolean halfline) {
		byte[] k = Arrays.copyOf(pic, pic.length + 3);
		k[pic.length] = (byte) p;
		k[pic.length + 1] = (byte) s;
		k[pic.length + 2] = (byte) f;
		return ByteBuffer.wrap(k);
	}

	private static List<Integer> words(int[] entries) {
		List<Integer> l = new ArrayList<Integer>(entries.length);
		for (int e : entries) {
			l.add(e);
		}
		return l;
	}

	/**
	 * Writes the result under dir : tiles.png (the tileset, a column of
	 * tiles), tiles.bin (its tile ids in order, 16 bit big endian : the map a
	 * &lt;tilemap&gt; turns into the page and address index), chunk_0.bin and
	 * chunk_1.bin (the banks), layout-&lt;n&gt;.bin (the acts, from 1),
	 * primary-collision.bin, secondary-collision.bin, flip-collision.bin.
	 */
	public static void write(Result r, Path dir) throws Exception {
		Files.createDirectories(dir);
		ImageIO.write(r.tiles, "png", dir.resolve("tiles.png").toFile());
		byte[] ids = new byte[r.tileCount * 2];
		for (int t = 0; t < r.tileCount; t++) {
			ids[t * 2] = (byte) (t >> 8);
			ids[t * 2 + 1] = (byte) t;
		}
		Files.write(dir.resolve("tiles.bin"), ids);
		for (int bank = 0; bank < 2; bank++) {
			int from = bank * BANK;
			int to = Math.min(r.chunks.size(), from + BANK);
			byte[] out = new byte[Math.max(0, to - from) * CELLS * CELLS * 2];
			for (int c = from; c < to; c++) {
				int[] entries = r.chunks.get(c);
				for (int i = 0; i < entries.length; i++) {
					int o = ((c - from) * CELLS * CELLS + i) * 2;
					out[o] = (byte) (entries[i] >> 8);
					out[o + 1] = (byte) entries[i];
				}
			}
			Files.write(dir.resolve("chunk_" + bank + ".bin"), out);
		}
		for (int a = 0; a < r.layouts.size(); a++) {
			Files.write(dir.resolve("layout-" + (a + 1) + ".bin"), r.layouts.get(a));
		}
		Files.write(dir.resolve("primary-collision.bin"), r.primary);
		Files.write(dir.resolve("secondary-collision.bin"), r.secondary);
		Files.write(dir.resolve("flip-collision.bin"), r.flip);
	}

	/**
	 * The animated blocks, declared {@code <block>[/high][/opaque]}, comma or
	 * space separated, in tile order.
	 */
	public static LinkedHashMap<Integer, Animated> parseAnimated(String spec) throws Exception {
		LinkedHashMap<Integer, Animated> out = new LinkedHashMap<Integer, Animated>();
		if (spec == null || spec.isBlank()) {
			return out;
		}
		for (String item : spec.trim().split("[,\\s]+")) {
			String[] parts = item.split("/");
			boolean high = false, full = false;
			for (int i = 1; i < parts.length; i++) {
				if ("high".equals(parts[i])) {
					high = true;
				} else if ("opaque".equals(parts[i])) {
					full = true;
				} else {
					throw new Exception("chunkmap : animated block '" + item + "' : unknown flag '" + parts[i]
							+ "' (high, opaque)");
				}
			}
			int b = Integer.decode(parts[0]);
			if (out.put(b, new Animated(high, full)) != null) {
				throw new Exception("chunkmap : animated block " + b + " declared twice");
			}
		}
		return out;
	}

	/** The conversion from files, the paths and flags as the element's attributes name them. */
	public static Result run(Path chunksPng, Path mappings, Path blocks, Path primary, Path secondary,
			List<Path> layouts, boolean halfline, boolean opaque, String animated, Path gendir) throws Exception {
		BufferedImage sheet = ImageIO.read(chunksPng.toFile());
		if (sheet == null) {
			throw new Exception("chunkmap : cannot read " + chunksPng);
		}
		List<byte[]> lay = new ArrayList<byte[]>();
		for (Path p : layouts) {
			lay.add(Files.readAllBytes(p));
		}
		Result r = convert(sheet, Files.readAllBytes(mappings), Files.readAllBytes(blocks),
				Files.readAllBytes(primary), Files.readAllBytes(secondary), lay, halfline, opaque,
				parseAnimated(animated));
		write(r, gendir);
		return r;
	}

	/**
	 * Standalone : {@code key=value} arguments named as the element's
	 * attributes, paths as they are (chunks, mappings, blocks, primary,
	 * secondary, layouts, gendir, halfline, opaque, animated).
	 */
	public static void main(String[] args) throws Exception {
		Map<String, String> a = new HashMap<String, String>();
		for (String arg : args) {
			int eq = arg.indexOf('=');
			if (eq < 0) {
				throw new Exception("chunkmap : argument '" + arg + "' is not key=value");
			}
			a.put(arg.substring(0, eq), arg.substring(eq + 1));
		}
		List<Path> layouts = new ArrayList<Path>();
		for (String l : a.get("layouts").split(",")) {
			layouts.add(Paths.get(l.trim()));
		}
		Result r = run(Paths.get(a.get("chunks")), Paths.get(a.get("mappings")), Paths.get(a.get("blocks")),
				Paths.get(a.get("primary")), Paths.get(a.get("secondary")), layouts,
				Boolean.parseBoolean(a.getOrDefault("halfline", "false")),
				Boolean.parseBoolean(a.getOrDefault("opaque", "false")), a.get("animated"),
				Paths.get(a.get("gendir")));
		System.out.println("chunkmap : " + r.tileCount + " tiles, " + r.chunks.size() + " chunks, "
				+ r.layouts.size() + " layouts under " + new File(a.get("gendir")));
	}
}
