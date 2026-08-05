package com.widedot.m6809.gamebuilder.plugin.scene;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import com.widedot.m6809.gamebuilder.spi.globals.LinkReport;
import com.widedot.m6809.gamebuilder.spi.globals.RamMap;

/**
 * What each scene keeps in the loader's memory pool.
 *
 * The RAM map says where a scene lands ; this says what it costs the loader to
 * link it. The two are read together, because they are the two budgets a new
 * object is placed against, and only one of them was measured until now.
 *
 * The loader holds one link block per indexed file for as long as that file
 * stays indexed, so a scene's demand is the sum over the files it loads. That
 * raw sum is not what the allocator has to serve, though : TLSF adds a header
 * to every block and rounds each request up to its size class. Both are counted
 * here, because it is the served size that fills the pool.
 *
 * Two things are deliberately NOT counted, and the report says so : the
 * directory, the scene file and the loader's slot table share the same pool,
 * and a scene swap allocates the incoming scene before releasing the outgoing
 * one. The builder does not model sequences of scenes (same reason as the RAM
 * map), so a scene's figure is a floor, not the peak. Read it as "at least
 * this much", and confirm on the machine with {@code tlsf.err} — see
 * {@code docs/lang/en/migration/static-link-bake.md}.
 */
public final class PoolMapReport {

	/** TLSF stores a size and a previous-physical pointer with every used block */
	private static final int BLOCK_HEADER = 4;

	/** smallest block TLSF will hand out : size, prev.phys, prev, next */
	private static final int MIN_BLOCK = 8;

	/** second level index width, tlsf.SL_BITS = 4 -> 16 classes per power of two */
	private static final int SL_CLASSES = 16;

	private PoolMapReport() {
	}

	/**
	 * What the allocator actually reserves for a request of {@code bytes}.
	 *
	 * Mirrors {@code engine/memory/malloc/tlsf.asm} : the header is added, the
	 * result is at least one whole block header, and it is rounded up to the
	 * granularity of its size class.
	 */
	static int served(int bytes) {
		int size = bytes + BLOCK_HEADER;
		if (size < MIN_BLOCK) {
			size = MIN_BLOCK;
		}
		int firstLevel = 31 - Integer.numberOfLeadingZeros(size);
		int granularity = Math.max(1, (1 << firstLevel) / SL_CLASSES);
		return (size + granularity - 1) / granularity * granularity;
	}

	/**
	 * @param declaredPool bytes declared by
	 *        {@code loader.DEFAULT_DYNAMIC_MEMORY_SIZE}, or -1 when the target
	 *        does not define it — the report is then drawn without a budget.
	 */
	public static String render(String targetName, RamMap map, LinkReport link, int declaredPool) {

		Map<String, Integer> cost = new LinkedHashMap<String, Integer>();
		for (LinkReport.Entry e : link.entries()) {
			cost.put(e.name, e.bytes);
		}

		String nl = System.lineSeparator();
		StringBuilder out = new StringBuilder();
		out.append("Link data pool of target ").append(targetName).append(nl);
		out.append("What each scene keeps in the loader's memory pool while it is indexed.").append(nl);
		out.append(nl);
		out.append("  served = the block TLSF really reserves : ")
		   .append(BLOCK_HEADER).append(" bytes of header, rounded up to the size class.").append(nl);
		out.append("  NOT counted : the directory, the scene file and the loader's slot table,").append(nl);
		out.append("  which share this pool ; and a scene swap holds both scenes at once.").append(nl);
		out.append("  A scene's total is therefore a FLOOR. Confirm on the machine with tlsf.err").append(nl);
		out.append("  (0 = fine, 3 = out of memory).").append(nl);
		out.append(nl);
		if (declaredPool >= 0) {
			out.append(String.format("loader.DEFAULT_DYNAMIC_MEMORY_SIZE = $%X (%d bytes)",
					declaredPool, declaredPool)).append(nl);
		} else {
			out.append("loader.DEFAULT_DYNAMIC_MEMORY_SIZE is not defined by this target"
					+ " — totals are shown without a budget.").append(nl);
		}
		out.append(nl);

		for (Map.Entry<String, List<RamMap.Load>> scene : map.scenes().entrySet()) {

			List<String> seen = new ArrayList<String>();
			int raw = 0;
			int servedTotal = 0;
			List<String[]> rows = new ArrayList<String[]>();

			for (RamMap.Load load : scene.getValue()) {
				Integer bytes = cost.get(load.name);
				// a file with no link block costs the pool nothing ; a file
				// loaded twice by the same scene is indexed once
				if (bytes == null || bytes == 0 || seen.contains(load.name)) {
					continue;
				}
				seen.add(load.name);
				int servedBytes = served(bytes);
				raw += bytes;
				servedTotal += servedBytes;
				rows.add(new String[] { String.valueOf(bytes), String.valueOf(servedBytes), load.name });
			}

			out.append("scene ").append(scene.getKey())
			   .append(" — ").append(seen.size()).append(" indexed file(s) carrying link data").append(nl);

			if (rows.isEmpty()) {
				out.append("  (nothing : every file this scene loads is fully baked)").append(nl).append(nl);
				continue;
			}

			// largest first : the arbitration order, same as the link report
			rows.sort((a, b) -> Integer.compare(Integer.parseInt(b[1]), Integer.parseInt(a[1])));

			out.append("     bytes   served  file").append(nl);
			for (String[] r : rows) {
				out.append(String.format("  %8s %8s  %s", r[0], r[1], r[2])).append(nl);
			}
			out.append("  --------- --------").append(nl);
			out.append(String.format("  %8d %8d  total", raw, servedTotal));

			if (declaredPool > 0) {
				int percent = servedTotal * 100 / declaredPool;
				out.append(String.format(" — %d%% of the pool, %d bytes left",
						percent, declaredPool - servedTotal));
				if (servedTotal > declaredPool) {
					out.append(nl).append("  ** OVER BUDGET : this scene cannot be linked."
							+ " Bake references, or raise the pool. **");
				}
			}
			out.append(nl).append(nl);
		}

		return out.toString();
	}
}
