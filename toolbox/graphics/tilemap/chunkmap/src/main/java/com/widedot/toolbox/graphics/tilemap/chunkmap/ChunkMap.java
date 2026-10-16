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
 * index (0-9, or 0-10 without the opaque bit) ; an empty cell is a zero
 * word (tile 0 has collision index 0 : its solidity is moot, and the
 * engine skips a zero word). The chunks are merged when
 * their 64 entries are the same, renumbered in the order the acts use them,
 * chunk 0 the empty one, and split in banks of 128 ;</li>
 * <li>each act's plane on the zone's chunk ids, 128 bytes a row ;</li>
 * <li>a collision byte per tile and layer, and the flip (the bits of the
 * chunk entry) the collision reads.</li>
 * </ul>
 *
 * Blocks drawn at run time (animated : the source maps them past its block
 * mappings, or the game redraws them over its mappings) are declared, with
 * the flip they are used with ; each takes the tile index past the tileset,
 * in the declared order, where the game's animated tilesets follow its
 * index, and its collision follows the tileset's in the collision tables.
 */
public final class ChunkMap {

	/** Blocks a chunk holds per row and per column. */
	public static final int CELLS = 8;
	/** Chunks a bank holds. */
	public static final int BANK = 128;
	/** Chunks the engine addresses by default : two banks, a byte a layout cell. */
	public static final int MAX_CHUNKS = 2 * BANK;
	/**
	 * Banks a map may have (16/10/2026) : past two, the layouts are written
	 * in words (big endian, rows of 256 bytes) and the engine reads them so
	 * (TilemapBuffer's word layout, its bank table of four).
	 */
	public static final int MAX_BANKS = 4;

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
		/** With {@code split} : each slice's chunks (its own ids, holes null) ; else null. */
		public final List<Slice> slices;
		/** The chunk banks written (two : the layouts in bytes ; more : in words). */
		public final int banks;

		Result(BufferedImage tiles, int tileCount, List<int[]> chunks, List<byte[]> layouts,
				byte[] primary, byte[] secondary, byte[] flip) {
			this(tiles, tileCount, chunks, layouts, primary, secondary, flip, null);
		}

		Result(BufferedImage tiles, int tileCount, List<int[]> chunks, List<byte[]> layouts,
				byte[] primary, byte[] secondary, byte[] flip, List<Slice> slices) {
			this(tiles, tileCount, chunks, layouts, primary, secondary, flip, slices, 2);
		}

		Result(BufferedImage tiles, int tileCount, List<int[]> chunks, List<byte[]> layouts,
				byte[] primary, byte[] secondary, byte[] flip, List<Slice> slices, int banks) {
			this.banks = banks;
			this.tiles = tiles;
			this.tileCount = tileCount;
			this.chunks = chunks;
			this.layouts = layouts;
			this.primary = primary;
			this.secondary = secondary;
			this.flip = flip;
			this.slices = slices;
		}
	}

	/**
	 * A slice of an act's plane (with {@code split}) : the columns from
	 * {@code first} to {@code last} (included), its chunks numbered on their
	 * own, in two banks the game swaps in when the camera enters the slice.
	 * Two neighbouring slices overlap : the columns both hold have the same
	 * ids in both, so the plane's ids hold whichever slice is in.
	 */
	public static final class Slice {
		public final int act;
		public final int first;
		public final int last;
		public final List<int[]> chunks = new ArrayList<int[]>();

		Slice(int act, int first, int last) {
			this.act = act;
			this.first = first;
			this.last = last;
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
	 * @param animated  blocks drawn at run time, keyed by block index and flip
	 *                  (bits 10-11, the mapping word's), in tile order
	 */
	public static Result convert(BufferedImage sheet, byte[] mappings, byte[] blocks, byte[] primary,
			byte[] secondary, List<byte[]> layouts, boolean halfline, boolean opaque,
			LinkedHashMap<Integer, Animated> animated) throws Exception {
		return convert(sheet, mappings, blocks, primary, secondary, layouts, halfline, opaque, animated, false,
				null, 0);
	}

	/**
	 * @param words   the layouts' entries are big endian words (rows of 256 :
	 *                the source has more than 256 chunks)
	 * @param split   per act (from 0), the columns where its plane is cut in
	 *                slices (null : the zone's chunks in two banks, the
	 *                usual case) ; with it, every act is cut in slices, an act
	 *                without a cut one slice
	 * @param overlap columns each side of a cut both slices hold
	 */
	public static Result convert(BufferedImage sheet, byte[] mappings, byte[] blocks, byte[] primary,
			byte[] secondary, List<byte[]> layouts, boolean halfline, boolean opaque,
			LinkedHashMap<Integer, Animated> animated, boolean words, Map<Integer, int[]> split, int overlap)
			throws Exception {
		return convert(sheet, mappings, blocks, primary, secondary, layouts, halfline, opaque, animated, words,
				split, overlap, 2);
	}

	/**
	 * @param banks the chunk banks of 128 the map may fill (2 to
	 *              {@link #MAX_BANKS}) : past two, the layouts are written in
	 *              words
	 */
	public static Result convert(BufferedImage sheet, byte[] mappings, byte[] blocks, byte[] primary,
			byte[] secondary, List<byte[]> layouts, boolean halfline, boolean opaque,
			LinkedHashMap<Integer, Animated> animated, boolean words, Map<Integer, int[]> split, int overlap,
			int banks) throws Exception {
		if (banks < 2 || banks > MAX_BANKS) {
			throw new Exception("chunkmap : banks=\"" + banks + "\", from 2 to " + MAX_BANKS);
		}
		final int maxChunks = banks * BANK;

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

		int rowBytes = words ? 512 : 256;
		List<int[]> sources = new ArrayList<int[]>();
		for (byte[] layout : layouts) {
			if (layout.length % rowBytes != 0) {
				throw new Exception("chunkmap : a layout of " + layout.length
						+ " bytes, not a whole number of " + rowBytes + " byte rows");
			}
			int rows = layout.length / rowBytes;
			int[] src0 = new int[rows * 128];
			for (int y = 0; y < rows; y++) {
				for (int x = 0; x < 128; x++) {
					int c = words ? (layout[y * 512 + 2 * x] & 0xFF) << 8 | (layout[y * 512 + 2 * x + 1] & 0xFF)
							: layout[y * 256 + x] & 0xFF;
					if (c >= sourceChunks) {
						throw new Exception("chunkmap : the layout uses chunk " + c + ", the mappings hold "
								+ sourceChunks);
					}
					src0[y * 128 + x] = c;
				}
			}
			sources.add(src0);
		}

		// each source chunk's entries (the tiles made on the way)
		Map<Integer, int[]> entriesOf = new HashMap<Integer, int[]>();
		entriesOf.put(0, new int[CELLS * CELLS]);
		for (int[] src0 : sources) {
			for (int c : src0) {
				if (!entriesOf.containsKey(c)) {
						int[] entries = new int[CELLS * CELLS];
						for (int i = 0; i < CELLS * CELLS; i++) {
							int o = (c * CELLS * CELLS + i) * 2;
							int w = (mappings[o] & 0xFF) << 8 | (mappings[o + 1] & 0xFF);
							int b = w & 0x3FF;
							int f = (w >> 10) & 3;
							int solidity = (w >> 12) & 0xF;
							int word;
							if (animated.containsKey(b | f << 10)) {
								Animated a = animated.get(b | f << 10);
								// patched past the tileset once its size is known
								word = (a.high ? 0x8000 : 0) | solidity << 11 | (opaque && a.opaque ? 0x400 : 0)
										| (0x10000 + animatedOrder.indexOf(b | f << 10));
							} else {
								for (int k : animatedOrder) {
									if ((k & 0x3FF) == b) {
										throw new Exception("chunkmap : chunk " + c + " uses animated block " + b
												+ flipName(f) + ", not declared so");
									}
								}
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
								boolean full = covers(pic, tw, th, halfline);
								// an empty cell is a zero word : the engine reads it so (nothing
								// drawn, no high priority queued : a tile of page 0 ends that
								// queue), and its collision index 0 leaves its solidity moot
								word = t == 0 ? 0 : (high ? 0x8000 : 0) | solidity << 11 | (opaque && full ? 0x400 : 0) | t;
							}
							entries[i] = word;
						}
						entriesOf.put(c, entries);
				}
			}
		}

		List<byte[]> outLayouts = new ArrayList<byte[]>();
		List<Slice> slices = null;
		if (split == null) {
			// the zone's chunks, merged when the same, in the order the acts use them
			for (int[] src0 : sources) {
				int[] out = new int[src0.length];
				for (int j = 0; j < src0.length; j++) {
					int c = src0[j];
					Integer z = zoneChunk.get(c);
					if (z == null) {
						int[] entries = entriesOf.get(c);
						List<Integer> k = words(entries);
						z = chunkOf.get(k);
						if (z == null) {
							z = chunks.size();
							chunkOf.put(k, z);
							chunks.add(entries);
						}
						zoneChunk.put(c, z);
					}
					out[j] = z;
				}
				outLayouts.add(cells(out, banks));
			}
			if (chunks.size() > maxChunks) {
				throw new Exception("chunkmap : " + chunks.size() + " chunks, its " + banks + " banks hold "
						+ maxChunks + " (banks=\"n\", up to " + MAX_BANKS + ")");
			}
		} else {
			slices = new ArrayList<Slice>();
			for (int a = 0; a < sources.size(); a++) {
				int[] src0 = sources.get(a);
				int rows = src0.length / 128;
				int width = 0;
				for (int j = 0; j < src0.length; j++) {
					if (src0[j] != 0) {
						width = Math.max(width, j % 128 + 1);
					}
				}
				int[] cuts = split.getOrDefault(a, new int[0]);
				int[] out = new int[src0.length];
				Slice prev = null;
				Map<Integer, Integer> prevIds = null;
				for (int k = 0; k <= cuts.length; k++) {
					int first = k == 0 ? 0 : Math.max(0, cuts[k - 1] - overlap);
					int last = k == cuts.length ? Math.max(0, width - 1) : Math.min(127, cuts[k] + overlap - 1);
					Slice sl = new Slice(a, first, last);
					Map<List<Integer>, Integer> idOf = new HashMap<List<Integer>, Integer>();
					Map<Integer, Integer> ids = new HashMap<Integer, Integer>();
					int[][] table = new int[maxChunks][];
					table[0] = new int[CELLS * CELLS];
					idOf.put(words(table[0]), 0);
					ids.put(0, 0);
					// the columns this slice shares with the previous one : their ids
					if (prev != null) {
						for (int y = 0; y < rows; y++) {
							for (int x = first; x <= prev.last; x++) {
								int c = src0[y * 128 + x];
								int z = prevIds.get(c);
								table[z] = entriesOf.get(c);
								idOf.put(words(table[z]), z);
								ids.put(c, z);
							}
						}
					}
					int next = 1;
					for (int y = 0; y < rows; y++) {
						for (int x = first; x <= last; x++) {
							int c = src0[y * 128 + x];
							Integer z = ids.get(c);
							if (z == null) {
								List<Integer> key = words(entriesOf.get(c));
								z = idOf.get(key);
								if (z == null) {
									while (next < maxChunks && table[next] != null) {
										next++;
									}
									if (next >= maxChunks) {
										throw new Exception("chunkmap : act " + (a + 1) + "'s slice of columns " + first
												+ "-" + last + " holds more than " + maxChunks + " chunks : cut it more");
									}
									z = next;
									table[z] = entriesOf.get(c);
									idOf.put(key, z);
								}
								ids.put(c, z);
							}
							// a column two slices hold : the first's id stands, the same
							out[y * 128 + x] = z;
						}
					}
					int top = maxChunks;
					while (top > 0 && table[top - 1] == null) {
						top--;
					}
					for (int z = 0; z < top; z++) {
						sl.chunks.add(table[z]);
					}
					slices.add(sl);
					prev = sl;
					prevIds = ids;
				}
				outLayouts.add(cells(out, banks));
			}
			for (Slice sl : slices) {
				for (int[] e : sl.chunks) {
					if (e != null && !chunks.contains(e)) {
						chunks.add(e);
					}
				}
			}
		}

		int count = pictures.size();
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
		// the collision tables : the tileset's tiles, then the animated ones
		byte[] primaryOut = new byte[count + animated.size()];
		byte[] secondaryOut = new byte[count + animated.size()];
		byte[] flipOut = new byte[count + animated.size()];
		for (int i = 0; i < animatedOrder.size(); i++) {
			int b = animatedOrder.get(i) & 0x3FF;
			int p = b < primary.length ? primary[b] & 0xFF : 0;
			int s = b < secondary.length ? secondary[b] & 0xFF : 0;
			primaryOut[count + i] = (byte) p;
			secondaryOut[count + i] = (byte) s;
			flipOut[count + i] = (byte) ((p == 0 || p == 0xFF) && (s == 0 || s == 0xFF) ? 0 : animatedOrder.get(i) >> 10);
		}
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
		return new Result(tiles, count, chunks, outLayouts, primaryOut, secondaryOut, flipOut, slices, banks);
	}

	/** A layout's cells : a byte each with two banks, a big endian word past two. */
	static byte[] cells(int[] ids, int banks) {
		if (banks <= 2) {
			byte[] out = new byte[ids.length];
			for (int j = 0; j < ids.length; j++) {
				out[j] = (byte) ids[j];
			}
			return out;
		}
		byte[] out = new byte[ids.length * 2];
		for (int j = 0; j < ids.length; j++) {
			out[j * 2] = (byte) (ids[j] >> 8);
			out[j * 2 + 1] = (byte) ids[j];
		}
		return out;
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
		if (r.slices == null) {
			writeBanks(r.chunks, dir, "chunk_", r.banks);
		} else {
			// a slice's banks : chunk_<slice>_<bank>.bin ; slices.txt : act,
			// first and last column of each, in the order of the files
			StringBuilder sb = new StringBuilder();
			for (int k = 0; k < r.slices.size(); k++) {
				Slice sl = r.slices.get(k);
				writeBanks(sl.chunks, dir, "chunk_" + k + "_", r.banks);
				sb.append(sl.act + 1).append(' ').append(sl.first).append(' ').append(sl.last)
						.append(' ').append(sl.chunks.size()).append('\n');
			}
			Files.write(dir.resolve("slices.txt"), sb.toString().getBytes());
		}
		for (int a = 0; a < r.layouts.size(); a++) {
			Files.write(dir.resolve("layout-" + (a + 1) + ".bin"), r.layouts.get(a));
		}
		Files.write(dir.resolve("primary-collision.bin"), r.primary);
		Files.write(dir.resolve("secondary-collision.bin"), r.secondary);
		Files.write(dir.resolve("flip-collision.bin"), r.flip);
	}

	/** The banks of 128 chunks, 64 big endian words a chunk (a hole : an empty chunk). */
	private static void writeBanks(List<int[]> chunks, Path dir, String prefix, int banks) throws Exception {
		for (int bank = 0; bank < banks; bank++) {
			int from = bank * BANK;
			int to = Math.min(chunks.size(), from + BANK);
			// past two banks, an empty one still a chunk (a file the game
			// declares, never empty)
			byte[] out = new byte[Math.max(banks > 2 ? 1 : 0, to - from) * CELLS * CELLS * 2];
			for (int c = from; c < to; c++) {
				int[] entries = chunks.get(c);
				if (entries == null) {
					continue;
				}
				for (int i = 0; i < entries.length; i++) {
					int o = ((c - from) * CELLS * CELLS + i) * 2;
					out[o] = (byte) (entries[i] >> 8);
					out[o + 1] = (byte) entries[i];
				}
			}
			Files.write(dir.resolve(prefix + bank + ".bin"), out);
		}
	}

	/** {@code split} : {@code <act>:<column>[:<column>...]}, comma separated, acts from 1. */
	public static Map<Integer, int[]> parseSplit(String spec) throws Exception {
		if (spec == null || spec.isBlank()) {
			return null;
		}
		Map<Integer, int[]> out = new HashMap<Integer, int[]>();
		for (String item : spec.trim().split("[,\\s]+")) {
			String[] parts = item.split(":");
			int[] cols = new int[parts.length - 1];
			for (int i = 1; i < parts.length; i++) {
				cols[i - 1] = Integer.parseInt(parts[i]);
			}
			out.put(Integer.parseInt(parts[0]) - 1, cols);
		}
		return out;
	}

	private static String flipName(int f) {
		return ((f & 1) != 0 ? "/xflip" : "") + ((f & 2) != 0 ? "/yflip" : "");
	}

	/**
	 * The animated blocks, declared {@code <block>[/xflip][/yflip][/high][/opaque]},
	 * comma or space separated, in tile order ; a block used flipped is
	 * declared once for each flip it is used with (its frames are drawn so).
	 */
	public static LinkedHashMap<Integer, Animated> parseAnimated(String spec) throws Exception {
		LinkedHashMap<Integer, Animated> out = new LinkedHashMap<Integer, Animated>();
		if (spec == null || spec.isBlank()) {
			return out;
		}
		for (String item : spec.trim().split("[,\\s]+")) {
			String[] parts = item.split("/");
			boolean high = false, full = false;
			int f = 0;
			for (int i = 1; i < parts.length; i++) {
				if ("xflip".equals(parts[i])) {
					f |= 1;
				} else if ("yflip".equals(parts[i])) {
					f |= 2;
				} else if ("high".equals(parts[i])) {
					high = true;
				} else if ("opaque".equals(parts[i])) {
					full = true;
				} else {
					throw new Exception("chunkmap : animated block '" + item + "' : unknown flag '" + parts[i]
							+ "' (xflip, yflip, high, opaque)");
				}
			}
			int b = Integer.decode(parts[0]);
			if (b < 0 || b > 0x3FF) {
				throw new Exception("chunkmap : animated block " + b + " past the mapping word's 10 bits");
			}
			if (out.put(b | f << 10, new Animated(high, full)) != null) {
				throw new Exception("chunkmap : animated block " + b + flipName(f) + " declared twice");
			}
		}
		return out;
	}

	/** The conversion from files, the paths and flags as the element's attributes name them. */
	public static Result run(Path chunksPng, Path mappings, Path blocks, Path primary, Path secondary,
			List<Path> layouts, boolean halfline, boolean opaque, String animated, Path gendir) throws Exception {
		return run(chunksPng, mappings, blocks, primary, secondary, layouts, halfline, opaque, animated, gendir,
				false, null, 0);
	}

	public static Result run(Path chunksPng, Path mappings, Path blocks, Path primary, Path secondary,
			List<Path> layouts, boolean halfline, boolean opaque, String animated, Path gendir, boolean words,
			String split, int overlap) throws Exception {
		return run(chunksPng, mappings, blocks, primary, secondary, layouts, halfline, opaque, animated, gendir,
				words, split, overlap, 2);
	}

	public static Result run(Path chunksPng, Path mappings, Path blocks, Path primary, Path secondary,
			List<Path> layouts, boolean halfline, boolean opaque, String animated, Path gendir, boolean words,
			String split, int overlap, int banks) throws Exception {
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
				parseAnimated(animated), words, parseSplit(split), overlap, banks);
		write(r, gendir);
		return r;
	}

	/**
	 * Standalone : {@code key=value} arguments named as the element's
	 * attributes, paths as they are (chunks, mappings, blocks, primary,
	 * secondary, layouts, gendir, halfline, opaque, animated, words, split, overlap).
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
				Paths.get(a.get("gendir")), Boolean.parseBoolean(a.getOrDefault("words", "false")), a.get("split"),
				Integer.parseInt(a.getOrDefault("overlap", "4")), Integer.parseInt(a.getOrDefault("banks", "2")));
		System.out.println("chunkmap : " + r.tileCount + " tiles, " + r.chunks.size() + " chunks, "
				+ r.layouts.size() + " layouts under " + new File(a.get("gendir")));
	}
}
