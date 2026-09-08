package com.widedot.m6809.gamebuilder.report;

import java.util.ArrayList;
import java.util.List;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.globals.Compositions;

/**
 * What loading each declared state costs the drive, as text : the chain of
 * states in declaration order, each converged from the previous one, with
 * every read the loader makes — directory, scene table, file data, link
 * data — where it is on the disk, and what the mechanical model of
 * {@link HeadPath} charges for it. The occupancy page draws the same walk
 * and lets the reader change the model's parameters ; this file is the
 * diffable version, at the defaults.
 *
 * The reading to aim for : a state whose scenes are shared with no other
 * state should read as ONE forward walk — its directory, then its tables
 * and files in reading order. A return to a lower track is the media's
 * declaration order, or a directory/table/link section sitting away from
 * the data, costing real time ; {@code <directory colocate="true">} with
 * tables and link data in the data section is what removes it.
 *
 * A read-only consumer : nothing here changes an image.
 */
public final class SeekReport {

	private SeekReport() {
	}

	public static String render(String targetName, BuildContext ctx) {
		StringBuilder out = new StringBuilder();
		HeadPath.Model model = HeadPath.build(ctx);
		HeadPath.Params p = new HeadPath.Params();
		out.append("seek report — target ").append(targetName).append('\n');
		out.append("every read the loader makes to converge from one declared state to the next,\n");
		out.append("in declaration order ; a state alone is read from nothing. Times are a model :\n");
		out.append(String.format("seek = tracks x %.0f ms + %.0f ms settle, %d rpm, a sector busy for %.0f %% of its slot, %.0f ms between sectors,\n",
				p.stepMs, p.settleMs, p.rpm, p.sectorFrac * 100, p.overheadMs));
		out.append("the disk keeps spinning and a sector is read when its slot comes by.\n");
		out.append("'<< back' marks a read on a lower track than the previous one.\n");

		for (HeadPath.Disk disk : model.disks) {
			out.append('\n').append("== ").append(disk.instance.name)
			   .append(" (").append(disk.instance.tracks).append(" tracks x ")
			   .append(disk.instance.faces).append(" faces, interleave ")
			   .append(disk.instance.softskip).append(", skew ").append(disk.instance.softskew)
			   .append(")\n");
			HeadPath.State st = new HeadPath.State();
			List<String> from = new ArrayList<String>();
			double chainMs = 0;
			for (Compositions.Composition c : model.chain) {
				HeadPath.Result r = HeadPath.simulate(model, disk, from, c.scenes, st, p);
				if (r.steps.isEmpty()) {
					from = c.scenes;
					continue;
				}
				chainMs += r.totalMs();
				out.append(String.format("%n%s -> %s : %.2f s (seek %.2f s over %d seek%s, %d tracks ; %d sectors, %d cached, %d lost turn%s)%s%n",
						from.isEmpty() ? "(nothing)" : previousName(model, from), c.name,
						r.totalMs() / 1000, r.seekMs / 1000, r.seeks, r.seeks == 1 ? "" : "s",
						r.tracksTravelled, r.sectors, r.cached, r.lostTurns,
						r.lostTurns == 1 ? "" : "s",
						r.elsewhere > 0 ? " — " + r.elsewhere + " read(s) not on this disk" : ""));
				int prevTrack = -1;
				for (HeadPath.Step s : r.steps) {
					if (s.elsewhere) {
						out.append(String.format("    %-6s %-28s (not on this disk)%n", s.kind, s.name));
						continue;
					}
					String mark = prevTrack >= 0 && s.track < prevTrack
							? String.format("  << back from t%d", prevTrack) : "";
					out.append(String.format("    %-6s %-28s f%d t%d..t%d s%-2d %3d sect%s %6.0f ms%s%n",
							s.kind, s.name, s.face, s.track, s.lastTrack, s.sector, s.sectors,
							s.cached > 0 ? " +" + s.cached + "c" : "   ",
							s.totalMs(), mark));
					prevTrack = s.lastTrack;
				}
				from = c.scenes;
			}
			out.append(String.format("%nwhole chain : %.2f s%n", chainMs / 1000));
		}
		return out.toString();
	}

	private static String previousName(HeadPath.Model model, List<String> scenes) {
		for (Compositions.Composition c : model.chain) {
			if (c.scenes.equals(scenes)) {
				return c.name;
			}
		}
		return "(state)";
	}
}
