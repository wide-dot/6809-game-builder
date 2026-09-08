package com.widedot.m6809.gamebuilder.report;

import static org.junit.jupiter.api.Assertions.*;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Interleave;
import com.widedot.m6809.gamebuilder.spi.globals.Compositions;
import com.widedot.m6809.gamebuilder.spi.globals.Occupancy;

/**
 * The mechanical model on a synthetic fd640 : what the numbers must mean.
 * The page's script re-implements the same walk ; these are the facts it
 * has to reproduce.
 */
class HeadPathTest {

	private static final int SECTORS = 16;

	private static HeadPath.Disk fd640() {
		Interleave il = new Interleave(7, 2, 4, SECTORS);
		int[] slotOfNumber = new int[SECTORS];
		for (int slot = 0; slot < SECTORS; slot++) {
			slotOfNumber[il.hardMap[slot] - 1] = slot;
		}
		int[] skew = new int[il.skewPeriod()];
		for (int t = 0; t < skew.length; t++) {
			skew[t] = il.skewIndex(t);
		}
		return new HeadPath.Disk(new Occupancy.Instance("to8.fd", 655360, 2, 80, SECTORS, 256,
				2, 4, 7, il.softMap.clone(), slotOfNumber, skew));
	}

	/** an element of n whole sectors starting at (face, track, k) */
	private static HeadPath.Element element(HeadPath.Disk disk, String key, String kind,
			int face, int track, int k, int n, boolean partialFirst, boolean partialLast) {
		HeadPath.Element el = new HeadPath.Element(key, kind, key, -1);
		// the media's write order : sector, then face, then track (FdUtil.nextSector)
		int f = face, t = track, s = k;
		for (int i = 0; i < n; i++) {
			el.sectors.add(Integer.valueOf((f * 80 + t) * SECTORS + s));
			if (++s == SECTORS) {
				s = 0;
				if (++f == 2) {
					f = 0;
					t++;
				}
			}
		}
		el.partialFirst = partialFirst;
		el.partialLast = partialLast;
		el.bytes = n * 256;
		disk.elements.put(key, el);
		return el;
	}

	private static HeadPath.Model model(HeadPath.Disk disk, String scene, int dir, String... files) {
		HeadPath.Model m = new HeadPath.Model();
		m.disks.add(disk);
		m.scenes.put(scene, new HeadPath.SceneLoad(scene, dir, new ArrayList<String>(Arrays.asList(files))));
		m.chain.add(new Compositions.Composition(scene, Arrays.asList(scene), ""));
		return m;
	}

	@Test
	@DisplayName("consecutive sectors at interleave 2 cost about two slots each, no seek within a track")
	void trackAtInterleaveTwo() {
		HeadPath.Disk disk = fd640();
		element(disk, "directory 0", "dir", 0, 0, 0, 1, false, false);
		element(disk, "s", "table", 0, 0, 1, 1, false, false);
		element(disk, "f", "data", 0, 8, 0, 16, false, false);
		HeadPath.Model m = model(disk, "s", 0, "f");
		HeadPath.Params p = new HeadPath.Params();
		p.overheadMs = 1;
		HeadPath.State st = new HeadPath.State();
		HeadPath.Result r = HeadPath.simulate(m, disk, new ArrayList<String>(), Arrays.asList("s"), st, p);
		assertEquals(3, r.steps.size());
		HeadPath.Step data = r.steps.get(2);
		assertEquals(16, data.sectors);
		assertEquals(1, data.seeks, "one seek from track 0 to track 8");
		assertEquals(8, data.tracksTravelled);
		assertEquals(8 * 4 + 25, data.seekMs, 0.001);
		// a whole track at interleave 2 is two revolutions, plus the wait for
		// the first slot after the seek (anything up to one revolution)
		double slot = 12.5;
		double took = data.waitMs + data.readMs;
		assertTrue(took < 2 * SECTORS * slot + SECTORS * slot + slot, "16 sectors took " + took + " ms");
		assertTrue(took > 2 * SECTORS * slot - 2 * slot, "16 sectors took " + took + " ms");
		assertEquals(0, data.lostTurns);
	}

	@Test
	@DisplayName("a partial sector still in ptsec is not read again ; a directory load empties the cache")
	void partialSectorCache() {
		HeadPath.Disk disk = fd640();
		element(disk, "directory 0", "dir", 0, 0, 0, 1, false, false);
		element(disk, "s", "table", 0, 0, 1, 1, false, false);
		element(disk, "a", "data", 0, 8, 0, 3, false, true);     // ends inside sector 2
		element(disk, "b", "data", 0, 8, 2, 2, true, false);     // starts inside that sector
		HeadPath.Model m = model(disk, "s", 0, "a", "b");
		HeadPath.Result r = HeadPath.simulate(m, disk, new ArrayList<String>(), Arrays.asList("s"),
				new HeadPath.State(), new HeadPath.Params());
		HeadPath.Step b = r.steps.get(3);
		assertEquals(1, b.cached);
		assertEquals(1, b.sectors);
		assertEquals(3, r.steps.get(2).sectors);

		// the same, with a directory read between the two : the cache is gone
		HeadPath.Disk disk2 = fd640();
		element(disk2, "directory 0", "dir", 0, 0, 0, 1, false, false);
		element(disk2, "directory 1", "dir", 0, 0, 3, 1, false, false);
		element(disk2, "s", "table", 0, 0, 1, 1, false, false);
		element(disk2, "t", "table", 0, 0, 2, 1, false, false);
		element(disk2, "a", "data", 0, 8, 0, 3, false, true);
		element(disk2, "b", "data", 0, 8, 2, 2, true, false);
		HeadPath.Model m2 = new HeadPath.Model();
		m2.disks.add(disk2);
		m2.scenes.put("s", new HeadPath.SceneLoad("s", 0, Arrays.asList("a")));
		m2.scenes.put("t", new HeadPath.SceneLoad("t", 1, Arrays.asList("b")));
		HeadPath.Result r2 = HeadPath.simulate(m2, disk2, new ArrayList<String>(),
				Arrays.asList("s", "t"), new HeadPath.State(), new HeadPath.Params());
		// dir 0, s, a, dir 1, t, b
		assertEquals(6, r2.steps.size());
		assertEquals(0, r2.steps.get(5).cached);
		assertEquals(2, r2.steps.get(5).sectors);
	}

	@Test
	@DisplayName("a face change is free, a track change is a seek ; departures re-read a table unless cached")
	void facesAndDepartures() {
		HeadPath.Disk disk = fd640();
		element(disk, "directory 0", "dir", 0, 0, 0, 1, false, false);
		element(disk, "s", "table", 0, 0, 1, 1, false, false);
		element(disk, "t", "table", 0, 0, 2, 1, false, false);
		element(disk, "f", "data", 0, 8, 14, 4, false, false);   // 2 on face 0, 2 on face 1
		element(disk, "g", "data", 1, 9, 0, 2, false, false);
		HeadPath.Model m = new HeadPath.Model();
		m.disks.add(disk);
		m.scenes.put("s", new HeadPath.SceneLoad("s", 0, Arrays.asList("f")));
		m.scenes.put("t", new HeadPath.SceneLoad("t", 0, Arrays.asList("g")));
		HeadPath.State st = new HeadPath.State();
		HeadPath.Params p = new HeadPath.Params();
		HeadPath.Result r = HeadPath.simulate(m, disk, new ArrayList<String>(), Arrays.asList("s"), st, p);
		HeadPath.Step f = r.steps.get(2);
		assertEquals(1, f.seeks, "track 0 -> 8 only : the face change costs nothing");
		assertEquals(4, f.sectors);
		// s -> t : s departs, its table is the cached one (no read) ; t arrives
		HeadPath.Result r2 = HeadPath.simulate(m, disk, Arrays.asList("s"), Arrays.asList("t"), st, p);
		List<String> kinds = new ArrayList<String>();
		for (HeadPath.Step s : r2.steps) {
			kinds.add(s.kind + ":" + s.name);
		}
		assertEquals(Arrays.asList("table:t", "data:g"), kinds, "same directory, cached table");
		// t -> s : t's table is cached now, s's is read again
		HeadPath.Result r3 = HeadPath.simulate(m, disk, Arrays.asList("t"), Arrays.asList("s"), st, p);
		kinds.clear();
		for (HeadPath.Step s : r3.steps) {
			kinds.add(s.kind + ":" + s.name);
		}
		assertEquals(Arrays.asList("table:s", "data:f"), kinds);
	}
}
