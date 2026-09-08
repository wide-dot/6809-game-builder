package com.widedot.m6809.gamebuilder.plugin.scene;

import java.util.List;
import java.util.Map;

/**
 * Renders a scene table in the format loader.scene.apply consumes.
 *
 * The block types are never authored, the generator selects them : loads with
 * their own destination — including everything the builder placed itself,
 * region or arena — become one type %01 block of explicit
 * [page][address][file id] triplets ; export-only loads (link data only) are
 * grouped into one sequential block at (0,0), where nothing is ever written.
 *
 * A sequential list is emitted as %11 blocks — a shared destination, a start
 * id and a count, 7 bytes flat — one per run of ids that follow the exact
 * chain the loader walks (next id = id + blocks of the entry). The table lives
 * in the TLSF pool at load time, so every byte saved is RAM handed back to
 * the game. Ids are the builder's own doing (declaration order), so a lot
 * declared consecutively is one block ; a lot scattered across the directory
 * is several, and the build says so. The %10 encoding (a shared destination
 * and a LIST of ids) is gone with it (08/09/2026) : it tolerated an
 * uncertainty its emitter never had, and cost the loader a third walker.
 */
@lombok.extern.slf4j.Slf4j
public final class SceneGenerator {

	/** a load with a resolved destination of its own */
	public static class Placed {
		public final int page;
		public final int address;
		public final String symbol;

		public Placed(int page, int address, String symbol) {
			this.page = page;
			this.address = address;
			this.symbol = symbol;
		}
	}

	/** the type field keeps 14 bits for the file count */
	public static final int MAX_FILES = 0x3FFF;

	private SceneGenerator() {
	}

	/**
	 * @param idBlocks id and block count of every entry of the directory,
	 *                 used to detect id chains ; null disables the %11
	 *                 encoding
	 */
	public static String generate(String sceneName, List<Placed> placed,
			List<String> exportOnly, Map<String, int[]> idBlocks) throws Exception {

		if (placed.size() > MAX_FILES || exportOnly.size() > MAX_FILES) {
			throw new Exception("scene " + sceneName + " holds more than " + MAX_FILES + " files in one block");
		}

		StringBuilder out = new StringBuilder();
		out.append("        ; generated scene : ").append(sceneName).append('\n');

		if (!placed.isEmpty()) {
			out.append("        fdb   $4000+").append(placed.size())
			   .append("                  ; [type | nb files]\n\n");
			for (Placed load : placed) {
				out.append(String.format("        fcb   $%02X                      ; [destination - page id]%n", load.page));
				out.append(String.format("        fdb   $%04X                    ; [destination - address]%n", load.address));
				out.append("        fdb   ").append(load.symbol).append('\n');
				out.append('\n');
			}
		}

		if (!exportOnly.isEmpty()) {
			out.append("        ; link data only (export-only files)\n");
			int blocks = sequentialBlocks(out, 0, 0, exportOnly, idBlocks);
			if (blocks > 1) {
				log.info("scene {} : its {} export-only files are {} runs of consecutive ids,"
						+ " {} sequential blocks ({} bytes) — declaring them consecutively in the"
						+ " directory, in the scene's order, would make one",
						sceneName, exportOnly.size(), blocks, blocks, 7 * blocks);
			}
		}

		out.append("        fdb   0                        ; end marker\n");
		return out.toString();
	}

	/**
	 * The sequential blocks of a lot : one %11 block (7 bytes) per run of
	 * consecutive ids. Returns how many were emitted.
	 */
	private static int sequentialBlocks(StringBuilder out, int page, int address,
			List<String> symbols, Map<String, int[]> idBlocks) {
		int blocks = 0;
		int start = 0;
		while (start < symbols.size()) {
			int end = start + 1;
			while (end < symbols.size() && chained(symbols.get(end - 1), symbols.get(end), idBlocks)) {
				end++;
			}
			int count = end - start;
			out.append("        ; ").append(count).append(" consecutive id")
			   .append(count > 1 ? "s" : "").append(" : one %11 block, 7 bytes flat\n");
			out.append("        fdb   $C000+").append(count)
			   .append("                  ; [type | nb files]\n\n");
			out.append(String.format("        fcb   $%02X                      ; [destination - page id]%n", page));
			out.append(String.format("        fdb   $%04X                    ; [destination - address]%n", address));
			out.append("        fdb   ").append(symbols.get(start))
			   .append("                    ; [start file id]\n\n");
			blocks++;
			start = end;
		}
		return blocks;
	}

	/**
	 * The %11 walk of the loader : next id = id + 1 + compressed + linked,
	 * which is exactly the block count of the entry.
	 */
	private static boolean chained(String a, String b, Map<String, int[]> idBlocks) {
		if (idBlocks == null) {
			return false;
		}
		int[] ia = idBlocks.get(a);
		int[] ib = idBlocks.get(b);
		return ia != null && ib != null && ib[0] == ia[0] + ia[1];
	}
}
