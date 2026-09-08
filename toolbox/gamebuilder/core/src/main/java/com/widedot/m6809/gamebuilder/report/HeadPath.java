package com.widedot.m6809.gamebuilder.report;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.globals.Compositions;
import com.widedot.m6809.gamebuilder.spi.globals.DirReservations;
import com.widedot.m6809.gamebuilder.spi.globals.Occupancy;

/**
 * What the drive does to bring a declared state into RAM : the sectors the
 * loader reads, in the order it reads them, and what each costs in head
 * travel and rotation.
 *
 * <p>The model is the loader's own walk ({@code loader.composition.load}) :
 * the scenes the target state does not hold are unloaded (their directory,
 * their table unless it is the cached one), then every arriving scene is
 * read — its directory if it is not the one in memory, its table, the data
 * of its files in table order, then the link data of its files in table
 * order — and the whole state is linked once. Every read is a run of
 * sectors the loader walks logically (sector, then face, then track) and
 * the media stores interleaved : a logical sector's physical slot is what
 * the rotation waits for.</p>
 *
 * <p>The costs are a small mechanical model, not a measurement : a seek is
 * {@code |tracks| × step + settle}, a face change is free, the disk keeps
 * spinning during everything and a sector is read when its slot comes by —
 * so a seek longer than the skew loses a turn, exactly as on the machine.
 * The loader's {@code ptsec} cache is modelled (a partial sector still in
 * the buffer is not re-read). Step, settle and the per-sector overhead are
 * parameters : their defaults are guesses to calibrate on the real drive,
 * which is why the HTML report lets the reader change them and see the
 * totals move.</p>
 *
 * <p>Two consumers : the text seek report (defaults, declaration chain) and
 * the occupancy page, which carries the model as JSON and re-runs the same
 * simulation in the browser. The two implementations must agree ; the
 * shape of {@link #simulate} is the reference.</p>
 */
public final class HeadPath {

	private HeadPath() {
	}

	/**
	 * The assumptions ; see the class comment. {@code sectorFrac} is the part
	 * of a sector's slot that goes from its ID field to the end of its data :
	 * the controller is free again before the slot ends, and the gap left is
	 * what an interleave of 1 lives on.
	 */
	public static final class Params {
		public double stepMs = 4;
		public double settleMs = 25;
		public double overheadMs = 1;
		public int rpm = 300;
		public double sectorFrac = 0.8;
	}

	/** one thing the loader reads : a directory, a scene table, a file's data, its link data */
	public static final class Element {
		public final String key;
		public final String kind;    // dir, table, data, link, other
		public final String name;
		public final int dirId;      // for a directory, else -1
		/** sectors in write order : linear sector index on the media */
		public final List<Integer> sectors = new ArrayList<Integer>();
		public boolean partialFirst;
		public boolean partialLast;
		public int bytes;

		Element(String key, String kind, String name, int dirId) {
			this.key = key;
			this.kind = kind;
			this.name = name;
			this.dirId = dirId;
		}
	}

	public static final class Disk {
		public final Occupancy.Instance instance;
		public final Map<String, Element> elements = new LinkedHashMap<String, Element>();

		Disk(Occupancy.Instance instance) {
			this.instance = instance;
		}
	}

	/** a scene as the loader walks it : its directory, the files of its table in order */
	public static final class SceneLoad {
		public final String name;
		public final int dir;
		public final List<String> files;

		SceneLoad(String name, int dir, List<String> files) {
			this.name = name;
			this.dir = dir;
			this.files = files;
		}
	}

	public static final class Model {
		public final List<Disk> disks = new ArrayList<Disk>();
		public final Map<String, SceneLoad> scenes = new LinkedHashMap<String, SceneLoad>();
		/** the states in declaration order — the chain the report walks */
		public final List<Compositions.Composition> chain = new ArrayList<Compositions.Composition>();
	}

	public static String tableKey(String scene) {
		return scene;
	}

	public static String dataKey(String file) {
		return file;
	}

	public static String linkKey(String file) {
		return file + com.widedot.m6809.gamebuilder.plugin.direntry.DirEntryPlugin.LINKDATA_SUFFIX;
	}

	public static String dirKey(int id) {
		return "directory " + id;
	}

	// ------------------------------------------------------------ the model

	public static Model build(BuildContext ctx) {
		Model m = new Model();

		// which directory holds which file or scene
		Map<String, Integer> dirOf = new LinkedHashMap<String, Integer>();
		for (Map.Entry<Integer, DirReservations.Reservation> e : ctx.dirReservations.all().entrySet()) {
			for (String name : e.getValue().names) {
				dirOf.put(name, e.getKey());
			}
		}
		Set<String> sceneNames = new HashSet<String>(ctx.ramMap.tableOrder().keySet());

		for (Occupancy.Instance inst : ctx.occupancy.instances().values()) {
			Disk disk = new Disk(inst);
			int faceSectors = inst.tracks * inst.sectors;
			for (Occupancy.MediaWrite w : ctx.occupancy.writes()) {
				if (!w.instance.equals(inst.name) || w.length <= 0) {
					continue;
				}
				Element el = disk.elements.get(w.name);
				if (el == null) {
					String kind;
					int dirId = -1;
					if (w.name.startsWith("directory ")) {
						kind = "dir";
						try {
							dirId = Integer.parseInt(w.name.substring("directory ".length()).trim());
						} catch (NumberFormatException x) {
							dirId = -1;
						}
					} else if (w.name.endsWith(com.widedot.m6809.gamebuilder.plugin.direntry
							.DirEntryPlugin.LINKDATA_SUFFIX)) {
						kind = "link";
					} else if (sceneNames.contains(w.name)) {
						kind = "table";
					} else if (dirOf.containsKey(w.name)) {
						kind = "data";
					} else {
						kind = "other";
					}
					el = new Element(w.name, kind, w.name, dirId);
					el.partialFirst = (w.start % inst.sectorSize) != 0;
					disk.elements.put(w.name, el);
				}
				int first = w.start / inst.sectorSize;
				int last = (w.start + w.length - 1) / inst.sectorSize;
				for (int sec = first; sec <= last; sec++) {
					if (el.sectors.isEmpty() || el.sectors.get(el.sectors.size() - 1).intValue() != sec) {
						el.sectors.add(Integer.valueOf(sec));
					}
				}
				el.partialLast = ((w.start + w.length) % inst.sectorSize) != 0;
				el.bytes += w.length;
				if (faceSectors <= 0) {
					continue;
				}
			}
			m.disks.add(disk);
		}

		for (Map.Entry<String, List<String>> e : ctx.ramMap.tableOrder().entrySet()) {
			Integer dir = dirOf.get(e.getKey());
			m.scenes.put(e.getKey(), new SceneLoad(e.getKey(), dir == null ? -1 : dir.intValue(),
					new ArrayList<String>(e.getValue())));
		}

		if (ctx.compositions.isEmpty()) {
			// no declared state : every scene alone, from nothing — the
			// reading the seek report always gave
			for (String scene : m.scenes.keySet()) {
				List<String> one = new ArrayList<String>();
				one.add(scene);
				m.chain.add(new Compositions.Composition(scene, one, ""));
			}
		} else {
			m.chain.addAll(ctx.compositions.all());
		}
		return m;
	}

	// ------------------------------------------------------- the simulation

	/** one element read, with what it cost */
	public static final class Step {
		public String kind;
		public String name;
		public int face, track, sector;   // where its first sector is (sector 0-based logical)
		public int lastTrack;
		public int sectors;               // sectors read from the disk
		public int cached;                // sectors ptsec already held
		public int seeks;
		public int tracksTravelled;
		public double seekMs;
		public double waitMs;
		public double readMs;
		public double startMs;
		public int lostTurns;
		public boolean elsewhere;         // not on this disk

		public double totalMs() {
			return seekMs + waitMs + readMs;
		}
	}

	/** the drive between two convergences : what carries from one to the next */
	public static final class State {
		public int headTrack = 0;
		public Integer currentDir = null;
		public String cachedTable = null;
		public Integer ptsec = null;      // linear sector index in the partial buffer, or null
		public double timeMs = 0;         // the rotation phase carries with the time
	}

	public static final class Result {
		public final List<Step> steps = new ArrayList<Step>();
		public double seekMs, waitMs, readMs;
		public int seeks, tracksTravelled, sectors, cached, lostTurns, elsewhere;

		public double totalMs() {
			return seekMs + waitMs + readMs;
		}
	}

	/**
	 * Converge from one set of scenes to another on one disk, from the given
	 * drive state (updated in place : the next convergence starts where this
	 * one ends).
	 */
	public static Result simulate(Model model, Disk disk, List<String> from, List<String> to,
			State st, Params p) {
		Result r = new Result();
		Sim sim = new Sim(disk, st, p, r);
		Set<String> target = new HashSet<String>(to);
		Set<String> held = new HashSet<String>(from);

		// departures : the scenes the target does not hold
		for (String scene : from) {
			if (target.contains(scene)) {
				continue;
			}
			SceneLoad load = model.scenes.get(scene);
			if (load == null) {
				continue;
			}
			sim.dirLoad(load.dir);
			if (scene.equals(st.cachedTable)) {
				st.cachedTable = null;       // the cached table is walked, then freed
			} else {
				sim.read("table", tableKey(scene), scene);
			}
		}
		// arrivals : table, data of every file, then their link data
		for (String scene : to) {
			if (held.contains(scene)) {
				continue;
			}
			SceneLoad load = model.scenes.get(scene);
			if (load == null) {
				continue;
			}
			sim.dirLoad(load.dir);
			sim.read("table", tableKey(scene), scene);
			st.cachedTable = scene;
			for (String file : load.files) {
				sim.read("data", dataKey(file), file);
			}
			for (String file : load.files) {
				sim.read("link", linkKey(file), file);
			}
		}
		return r;
	}

	private static final class Sim {
		final Disk disk;
		final State st;
		final Params p;
		final Result r;
		final double slotMs;
		final int sectors;

		Sim(Disk disk, State st, Params p, Result r) {
			this.disk = disk;
			this.st = st;
			this.p = p;
			this.r = r;
			this.sectors = disk.instance.sectors;
			this.slotMs = 60000.0 / p.rpm / sectors;
		}

		void dirLoad(int dir) {
			if (dir < 0 || (st.currentDir != null && st.currentDir.intValue() == dir)) {
				return;
			}
			st.currentDir = Integer.valueOf(dir);
			read("dir", dirKey(dir), dirKey(dir));
			st.ptsec = null;                 // the loader invalidates its key
		}

		/** the physical slot of the logical sector k of a track */
		int slot(int track, int k) {
			Occupancy.Instance i = disk.instance;
			if (i.readOrder == null) {
				return k % sectors;
			}
			int skew = i.skewByTrack[track % i.skewByTrack.length];
			int number = i.readOrder[(skew + k) % sectors];
			return i.slotOfNumber[number - 1];
		}

		void read(String kind, String key, String name) {
			Element el = disk.elements.get(key);
			if (el == null) {
				if ("data".equals(kind) || "link".equals(kind)) {
					return;                  // an export-only file, or no link data : nothing to read
				}
				Step s = new Step();
				s.kind = kind;
				s.name = name;
				s.elsewhere = true;
				r.steps.add(s);
				r.elsewhere++;
				return;
			}
			Step s = new Step();
			s.kind = kind;
			s.name = name;
			s.startMs = st.timeMs;
			int perFace = disk.instance.tracks * sectors;
			boolean first = true;
			int n = el.sectors.size();
			for (int idx = 0; idx < n; idx++) {
				int lin = el.sectors.get(idx).intValue();
				int face = lin / perFace;
				int track = (lin % perFace) / sectors;
				int k = lin % sectors;
				if (first) {
					s.face = face;
					s.track = track;
					s.sector = k;
					first = false;
				}
				s.lastTrack = track;
				boolean partial = (idx == 0 && el.partialFirst) || (idx == n - 1 && el.partialLast);
				if (partial && st.ptsec != null && st.ptsec.intValue() == lin) {
					s.cached++;
					continue;                // ptsec already holds it : no disk access
				}
				// seek
				boolean sought = false;
				if (track != st.headTrack) {
					int d = Math.abs(track - st.headTrack);
					s.seeks++;
					s.tracksTravelled += d;
					double ms = d * p.stepMs + p.settleMs;
					s.seekMs += ms;
					st.timeMs += ms;
					st.headTrack = track;
					sought = true;
				}
				// rotation : wait for the slot, then one slot to read it. A
				// long wait right after a seek is latency (the phase is
				// arbitrary) ; the same wait on a head that did not move is a
				// turn LOST — the slot went by before the loader asked for it
				double angle = (st.timeMs / slotMs) % sectors;
				double wait = ((slot(track, k) - angle) % sectors + sectors) % sectors;
				if (wait > sectors - 0.001) {
					wait = 0;
				}
				double waitMs = wait * slotMs;
				if (!sought && wait > sectors / 2.0) {
					s.lostTurns++;
				}
				double readMs = slotMs * p.sectorFrac;
				s.waitMs += waitMs;
				s.readMs += readMs;
				st.timeMs += waitMs + readMs + p.overheadMs;
				s.sectors++;
				if (partial) {
					st.ptsec = Integer.valueOf(lin);
				}
			}
			r.steps.add(s);
			r.seekMs += s.seekMs;
			r.waitMs += s.waitMs;
			r.readMs += s.readMs;
			r.seeks += s.seeks;
			r.tracksTravelled += s.tracksTravelled;
			r.sectors += s.sectors;
			r.cached += s.cached;
			r.lostTurns += s.lostTurns;
		}
	}
}
