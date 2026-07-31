package com.widedot.m6809.gamebuilder.plugin.scene;

import java.util.List;

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

	public static String generate(String sceneName, List<Placed> placed, List<Bulk> bulks,
			List<String> exportOnly) throws Exception {

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
			out.append("        fdb   $8000+").append(bulk.symbols.size())
			   .append("                  ; [type | nb files]\n\n");
			out.append(String.format("        fcb   $%02X                      ; [destination - page id]%n", bulk.page));
			out.append(String.format("        fdb   $%04X                    ; [destination - address]%n", bulk.address));
			for (String symbol : bulk.symbols) {
				out.append("        fdb   ").append(symbol).append('\n');
			}
			out.append('\n');
		}

		if (!exportOnly.isEmpty()) {
			out.append("        ; link data only (export-only files)\n");
			out.append("        fdb   $8000+").append(exportOnly.size())
			   .append("                  ; [type | nb files]\n\n");
			out.append("        fcb   0                        ; [destination - page id]\n");
			out.append("        fdb   0                        ; [destination - address]\n");
			for (String symbol : exportOnly) {
				out.append("        fdb   ").append(symbol).append('\n');
			}
			out.append('\n');
		}

		out.append("        fdb   0                        ; end marker\n");
		return out.toString();
	}
}
