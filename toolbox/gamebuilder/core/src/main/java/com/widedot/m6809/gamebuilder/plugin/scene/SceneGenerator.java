package com.widedot.m6809.gamebuilder.plugin.scene;

import java.util.List;
import java.util.Map;

/**
 * Renders a scene table in the format loader.scene.apply consumes.
 *
 * The block types are never authored, the generator selects them : loads with
 * their own destination become one type %01 block of explicit
 * [page][address][file id] triplets ; the loads of a bulk region become one
 * type %10 block (base destination + ids, laid out one after the other by the
 * loader) ; export-only loads (link data only) are grouped into one type %10
 * block at (0,0). This is exactly the structure of the handwritten tables it
 * replaces, which is what made the migration provable byte for byte.
 *
 * On top of that structure, a sequential list whose ids follow the exact
 * chain the loader walks (next id = id + blocks of the entry) is emitted as
 * one %11 block : 7 bytes flat instead of 5+2n. The table lives in the TLSF
 * pool at load time, so every byte saved is RAM handed back to the game. The
 * chain is re-checked at every build ; reordering the configuration silently
 * falls back to %10.
 */
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

	/** the loads of one bulk region : a base destination and an ordered list */
	public static class Bulk {
		public final int page;
		public final int address;
		public final List<String> symbols;

		public Bulk(int page, int address, List<String> symbols) {
			this.page = page;
			this.address = address;
			this.symbols = symbols;
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
	public static String generate(String sceneName, List<Placed> placed, List<Bulk> bulks,
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

		for (Bulk bulk : bulks) {
			if (bulk.symbols.size() > MAX_FILES) {
				throw new Exception("scene " + sceneName + " holds more than " + MAX_FILES + " files in one block");
			}
			out.append("        ; bulk region : files laid out one after the other\n");
			sequentialBlock(out, bulk.page, bulk.address, bulk.symbols, idBlocks);
		}

		if (!exportOnly.isEmpty()) {
			out.append("        ; link data only (export-only files)\n");
			sequentialBlock(out, 0, 0, exportOnly, idBlocks);
		}

		out.append("        fdb   0                        ; end marker\n");
		return out.toString();
	}

	/**
	 * One sequential block : %11 when the ids chain (7 bytes flat), %10
	 * otherwise (5 + 2n bytes).
	 */
	private static void sequentialBlock(StringBuilder out, int page, int address,
			List<String> symbols, Map<String, int[]> idBlocks) {
		if (chained(symbols, idBlocks)) {
			out.append("        ; consecutive ids : one %11 block, 7 bytes flat\n");
			out.append("        fdb   $C000+").append(symbols.size())
			   .append("                  ; [type | nb files]\n\n");
			out.append(String.format("        fcb   $%02X                      ; [destination - page id]%n", page));
			out.append(String.format("        fdb   $%04X                    ; [destination - address]%n", address));
			out.append("        fdb   ").append(symbols.get(0))
			   .append("                    ; [start file id]\n");
		} else {
			out.append("        fdb   $8000+").append(symbols.size())
			   .append("                  ; [type | nb files]\n\n");
			out.append(String.format("        fcb   $%02X                      ; [destination - page id]%n", page));
			out.append(String.format("        fdb   $%04X                    ; [destination - address]%n", address));
			for (String symbol : symbols) {
				out.append("        fdb   ").append(symbol).append('\n');
			}
		}
		out.append('\n');
	}

	/**
	 * The %11 walk of the loader : next id = id + 1 + compressed + linked,
	 * which is exactly the block count of the entry.
	 */
	private static boolean chained(List<String> symbols, Map<String, int[]> idBlocks) {
		if (symbols.size() < 2 || idBlocks == null) {
			return false;
		}
		for (int k = 0; k + 1 < symbols.size(); k++) {
			int[] a = idBlocks.get(symbols.get(k));
			int[] b = idBlocks.get(symbols.get(k + 1));
			if (a == null || b == null || b[0] != a[0] + a[1]) {
				return false;
			}
		}
		return true;
	}
}
