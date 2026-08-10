package com.widedot.m6809.gamebuilder.report;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.globals.Occupancy;
import com.widedot.m6809.gamebuilder.spi.globals.RamMap;

/**
 * What loading each scene costs the drive's head : the tracks it visits, in
 * the order the loader reads them, and every time it has to come back.
 *
 * The loader reads a scene's files in table order, and the media writes them
 * in declaration order — two orders nothing reconciles today. The difference
 * is paid in head seeks, the slowest thing a floppy does. This report makes
 * that cost visible per scene, from facts the build already holds : the
 * media journal (where every byte landed) and the RAM map (what each scene
 * loads, in order).
 *
 * The reading to aim for : a scene whose files are shared with no other
 * scene should show ZERO head returns — its files can always be written in
 * its own reading order. Returns on such a scene are the media's declaration
 * order costing real time, and the target model derives the write order from
 * the scenes to make them vanish (phase 6 of the migration plan). Shared
 * files (two scenes reading one file) are where returns are structural ;
 * they are the residue the report leaves visible.
 *
 * A read-only consumer : nothing here changes an image.
 */
public final class SeekReport {

	private SeekReport() {
	}

	/** one file's place on the media, reduced to the cylinders it spans */
	private static class Span {
		final int first;
		final int last;

		Span(int first, int last) {
			this.first = first;
			this.last = last;
		}
	}

	public static String render(String targetName, BuildContext ctx) {
		StringBuilder out = new StringBuilder();
		out.append("seek report — target ").append(targetName).append('\n');
		out.append("what the head travels to load each scene, in table order.\n");
		out.append("a scene sharing no file with another scene should read ZERO returns ;\n");
		out.append("a return there is the media's declaration order costing real time.\n");

		for (Occupancy.Instance media : ctx.occupancy.instances().values()) {
			int trackSize = media.sectors * media.sectorSize;
			int faceSize = media.tracks * trackSize;

			// where each named write landed, in cylinders, write order kept
			Map<String, List<Span>> spans = new LinkedHashMap<String, List<Span>>();
			Integer directoryTrack = null;
			for (Occupancy.MediaWrite w : ctx.occupancy.writes()) {
				if (!w.instance.equals(media.name) || w.length <= 0) {
					continue;
				}
				int first = (w.start % faceSize) / trackSize;
				int last = ((w.start + w.length - 1) % faceSize) / trackSize;
				spans.computeIfAbsent(w.name, n -> new ArrayList<Span>())
						.add(new Span(first, last));
				if (directoryTrack == null && w.name.startsWith("directory")) {
					directoryTrack = first;
				}
			}
			if (spans.isEmpty()) {
				continue;
			}
			int start = directoryTrack == null ? 0 : directoryTrack;

			out.append('\n').append("== ").append(media.name)
			   .append(" (").append(media.tracks).append(" tracks x ")
			   .append(media.faces).append(" faces, directory at track ").append(start)
			   .append(")\n");

			for (Map.Entry<String, List<RamMap.Load>> scene : ctx.ramMap.scenes().entrySet()) {
				List<String> lines = new ArrayList<String>();
				int head = start;
				int returns = 0;
				int travelled = 0;
				int elsewhere = 0;
				for (RamMap.Load load : scene.getValue()) {
					List<Span> pieces = spans.get(load.name);
					if (pieces == null) {
						elsewhere++;    // another disk, or nothing written for it
						continue;
					}
					int first = pieces.get(0).first;
					int last = first;
					for (Span s : pieces) {
						last = Math.max(last, s.last);
					}
					String mark = "";
					if (first < head) {
						returns++;
						mark = String.format("  << back from t%d", head);
					}
					travelled += Math.abs(first - head) + (last - first);
					head = last;
					lines.add(String.format("    %-28s t%d..t%d%s", load.name, first, last, mark));
				}
				if (lines.isEmpty()) {
					continue;
				}
				out.append(String.format("%s : %d return%s, %d tracks travelled%s%n",
						scene.getKey(), returns, returns == 1 ? "" : "s", travelled,
						elsewhere > 0 ? ", " + elsewhere + " load(s) not on this media" : ""));
				for (String line : lines) {
					out.append(line).append('\n');
				}
			}
		}
		return out.toString();
	}
}
