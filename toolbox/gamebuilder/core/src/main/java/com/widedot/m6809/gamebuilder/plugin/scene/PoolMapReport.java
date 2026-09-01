package com.widedot.m6809.gamebuilder.plugin.scene;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import com.widedot.m6809.gamebuilder.spi.globals.Compositions;
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
 * A scene's own figure is a FLOOR : it says what that scene costs, not what
 * the machine holds, because what else is resident beside it is precisely what
 * a scene cannot say.
 *
 * <p>A <b>composition</b> can. When the configuration declares its RAM states,
 * the report leads with them, and their largest is the <b>peak</b> — the real
 * number to place the pool against. Two properties make it a peak and not
 * another floor : the loader keeps one link block per indexed file for as long
 * as it stays indexed, so a state's demand is the sum over every file it holds ;
 * and {@code loader.composition.load} drops before it loads, so a transition
 * never holds two states at once. What remains uncounted is small and named
 * below : one scene table in flight, and the loader's slot table.</p>
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
		return render(targetName, map, link, declaredPool, null);
	}

	public static String render(String targetName, RamMap map, LinkReport link, int declaredPool,
			Compositions compositions) {

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
		out.append("  NOT counted : the scene table in flight and the loader's slot table, which").append(nl);
		out.append("  share this pool. (The directory lives in its own static buffer, carved off").append(nl);
		out.append("  the pool head since 15/08.)").append(nl);
		boolean stated = compositions != null && !compositions.isEmpty();
		if (stated) {
			out.append("  A STATE's total is the peak : the loader holds one link block per indexed").append(nl);
			out.append("  file, and a convergence drops before it loads — two states are never held").append(nl);
			out.append("  at once. A scene's own total, further down, stays a floor.").append(nl);
		} else {
			out.append("  A scene's total is a FLOOR : what else is resident beside it is what a").append(nl);
			out.append("  scene cannot say. Declare <composition> states to get the peak.").append(nl);
		}
		out.append("  Confirm on the machine with tlsf.err (0 = fine, 3 = out of memory).").append(nl);
		out.append(nl);
		if (declaredPool >= 0) {
			out.append(String.format("loader.DEFAULT_DYNAMIC_MEMORY_SIZE = $%X (%d bytes)",
					declaredPool, declaredPool)).append(nl);
		} else {
			out.append("loader.DEFAULT_DYNAMIC_MEMORY_SIZE is not defined by this target"
					+ " — totals are shown without a budget.").append(nl);
		}
		out.append(nl);

		if (stated) {
			out.append("RAM states — what the pool must hold at once").append(nl);
			String peakName = null;
			int peak = -1;
			List<String[]> states = new ArrayList<String[]>();
			for (Compositions.Composition c : compositions.all()) {
				List<String> seen = new ArrayList<String>();
				int servedTotal = 0;
				int files = 0;
				for (String scene : c.scenes) {
					List<RamMap.Load> loads = map.scenes().get(scene);
					if (loads == null) {
						continue;
					}
					for (RamMap.Load load : loads) {
						Integer bytes = cost.get(load.name);
						if (bytes == null || bytes == 0 || seen.contains(load.name)) {
							continue;
						}
						seen.add(load.name);
						servedTotal += served(bytes);
						files++;
					}
				}
				states.add(new String[] { String.valueOf(servedTotal), String.valueOf(files), c.name });
				if (servedTotal > peak) {
					peak = servedTotal;
					peakName = c.name;
				}
			}
			out.append("    served    files  state").append(nl);
			for (String[] r : states) {
				out.append(String.format("  %8s %8s  %s", r[0], r[1], r[2])).append(nl);
			}
			if (peakName != null) {
				out.append("  --------").append(nl);
				out.append(String.format("  %8d           PEAK — state '%s'", peak, peakName));
				if (declaredPool > 0) {
					out.append(String.format(", %d%% of the pool, %d bytes left",
							peak * 100 / declaredPool, declaredPool - peak));
				}
				out.append(nl);
				if (declaredPool > 0 && peak > declaredPool) {
					out.append("  ** OVER BUDGET : this state cannot be linked."
							+ " Bake references, or raise the pool. **").append(nl);
				}
			}
			out.append(nl);
		}

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

			if (declaredPool > 0 && !stated) {
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
