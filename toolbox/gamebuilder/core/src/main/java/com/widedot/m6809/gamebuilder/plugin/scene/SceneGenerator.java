package com.widedot.m6809.gamebuilder.plugin.scene;

import java.util.List;

/**
 * Renders a scene table in the format loader.scene.apply consumes.
 *
 * The block types are never authored, the generator selects them : loads with
 * a destination become one type %01 block of explicit [page][address][file id]
 * triplets, export-only loads (link data only, no destination) are grouped
 * into one type %10 block at (0,0) — 2 bytes per file instead of 5. This is
 * exactly the structure of the handwritten tables it replaces, which is what
 * makes the migration provable byte for byte.
 */
public final class SceneGenerator {

	/** a load with a resolved destination */
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

	public static String generate(String sceneName, List<Placed> placed, List<String> exportOnly) throws Exception {

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
