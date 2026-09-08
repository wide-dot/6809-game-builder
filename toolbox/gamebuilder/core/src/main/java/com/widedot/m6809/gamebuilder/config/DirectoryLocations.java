package com.widedot.m6809.gamebuilder.config;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Handlers;
import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Interleave;
import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Section;
import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Storage;
import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Storages;
import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;

/**
 * Collects, from the raw configuration tree, where every {@code <directory>}
 * of the target lives on its media — physical disk, face, track, sector —
 * and writes the table the loader embeds
 * ({@code gen/directories/locations.asm}).
 *
 * <p>The loader keeps ONE directory in memory and reloads another on demand
 * ({@code loader.dir.load}) ; historically the location was a trio of
 * assembly constants, which forced every directory of a game to live at the
 * same spot on its own physical disk. This table lifts that : directories
 * are looked up by id, and the "Insert disk" prompt only fires when the
 * PHYSICAL disk differs from the one currently in the drive. Design :
 * docs/lang/fr/analyse-repertoires-partitionnes-2026-08.md.</p>
 *
 * <p>Pure configuration, like the rest of the placement scan : a directory's
 * spot is its section declaration, the physical disk is the rank of its
 * {@code <floppydisk>} in the target. Nothing here needs the build to have
 * started — which is the point, the loader is assembled long before the
 * directories are emitted.</p>
 */
@Slf4j
public final class DirectoryLocations {

	/** A resolved directory location : physical disk, face, track, sector (0-based). */
	private static final class Row {
		final int disk, face, track, sector;
		final String sectionName;
		final boolean colocated;
		Row(int disk, int face, int track, int sector, String sectionName, boolean colocated) {
			this.disk = disk; this.face = face; this.track = track;
			this.sector = sector; this.sectionName = sectionName;
			this.colocated = colocated;
		}
	}

	private DirectoryLocations() {
	}

	public static void generate(ImmutableNode targetNode, BuildContext ctx) throws Exception {
		List<Row> rows = new ArrayList<Row>();
		List<Interleave> interleaves = new ArrayList<Interleave>();
		walk(targetNode, ctx.child(), rows, new int[] { 0 }, interleaves);
		if (rows.isEmpty()) {
			return; // no <directory> in this target : nothing consumes the table
		}
		// ids are the table's indexes : they must be dense and start at zero,
		// or the loader would read a hole as a location
		for (int id = 0; id < rows.size(); id++) {
			if (rows.get(id) == null) {
				throw new Exception("directory ids must be contiguous from 0 : id " + id
						+ " is missing while " + (rows.size() - 1) + " exists");
			}
		}
		// the registry the emission completes : a colocated directory's row
		// stays unresolved until its <directory> is emitted, and every
		// resolution rewrites the table (see resolve)
		ctx.dirLocations.clear();
		for (int id = 0; id < rows.size(); id++) {
			Row r = rows.get(id);
			ctx.dirLocations.declare(id, new com.widedot.m6809.gamebuilder.spi.globals
					.DirLocations.Row(r.disk, r.sectionName, r.colocated,
							r.colocated ? null : new int[] { r.face, r.track, r.sector }));
		}
		// every floppy disk of the target is read by the one loader, so their
		// interleaves have to agree
		Interleave il = interleaves.get(0);
		for (int d = 1; d < interleaves.size(); d++) {
			if (!java.util.Arrays.equals(interleaves.get(d).softMap, il.softMap)
					|| interleaves.get(d).softskew != il.softskew) {
				throw new Exception("floppy disk " + d + " declares another interleave than disk 0 ; "
						+ "the loader reads every disk of a target with one table");
			}
		}
		ctx.dirLocations.trailer = interleaveBlock(il);
		write(ctx);
	}

	/**
	 * A colocated directory has just taken its sectors : record where, and
	 * rewrite the table for whoever assembles it from here on — the loader's
	 * {@code <data>}, declared after the directories, includes the resolved
	 * table ; the build cache follows includes, so the loader reassembles.
	 */
	public static void resolve(BuildContext ctx, int id, int face, int track, int sector)
			throws Exception {
		ctx.dirLocations.resolve(id, face, track, sector);
		if (ctx.dirLocations.trailer == null) {
			throw new Exception("directory locations : resolved before generated");
		}
		write(ctx);
	}

	private static void write(BuildContext ctx) throws Exception {
		int count = ctx.dirLocations.all().size();
		List<com.widedot.m6809.gamebuilder.spi.globals.DirLocations.Row> rows =
				new ArrayList<com.widedot.m6809.gamebuilder.spi.globals.DirLocations.Row>();
		for (int id = 0; id < count; id++) {
			rows.add(ctx.dirLocations.get(id));
		}
		StringBuilder out = new StringBuilder();
		out.append("* Generated by the builder - do not edit.")
		   .append(System.lineSeparator());
		out.append("* One entry per <directory> of the target, indexed by directory id :")
		   .append(System.lineSeparator());
		out.append("* [physical disk] [face] [track] [sector 0-based]")
		   .append(System.lineSeparator());
		out.append("loader.dir.location.SIZE equ 4").append(System.lineSeparator());
		out.append("loader.dir.count equ ").append(rows.size()).append(System.lineSeparator());
		// a MACRO, not data : this file is included at the top of the loader
		// assembly, BEFORE its org — bytes emitted here would land outside
		// the raw binary (measured at address 0). The loader invokes the
		// macro where its own layout wants the table.
		out.append("_loader.dir.locations.table MACRO").append(System.lineSeparator());
		for (int id = 0; id < rows.size(); id++) {
			com.widedot.m6809.gamebuilder.spi.globals.DirLocations.Row r = rows.get(id);
			if (!r.resolved()) {
				// a colocated directory not emitted yet : whoever expands the
				// table now would embed a zero the loader reads as a location
				out.append("        ERROR directory ").append(id)
				   .append(" is colocated and not emitted yet : its location is only known")
				   .append(" once its <directory> is written, declare the loader's <data>")
				   .append(" after the directories").append(System.lineSeparator());
				continue;
			}
			out.append("        fcb   ").append(r.disk).append(',').append(r.where[0])
			   .append(',').append(r.where[1]).append(',').append(r.where[2])
			   .append("   ; directory ").append(id)
			   .append(" (").append(r.section).append(r.colocated ? ", colocated" : "")
			   .append(')')
			   .append(System.lineSeparator());
		}
		out.append("        ENDM").append(System.lineSeparator());
		// the loader's current-disk variable starts on the disk that booted :
		// the one holding directory 0
		out.append("loader.dir.bootPhysicalDisk equ ").append(rows.get(0).disk)
		   .append(System.lineSeparator());

		// the biggest directory of the target, in sectors : the loader's
		// sanity cap on a directory header (a bigger one can only be a foreign
		// or corrupt disk). It sized a static buffer from 15/08 to 07/09/2026 ;
		// the buffer is allocated at the directory's own size since. Sizes
		// come from the reservations the placement scan just made (7-byte
		// header + blocks * BLOCK_SIZE, the exact formula the emission asserts
		// against).
		int maxSectors = 1;
		for (int id = 0; id < rows.size(); id++) {
			com.widedot.m6809.gamebuilder.spi.globals.DirReservations.Reservation r =
					ctx.dirReservations.get(id);
			if (r == null) {
				throw new Exception("directory " + id + " has no reservation — "
						+ "the placement scan must reserve before locations are generated");
			}
			int size = 7 + (r.endId - r.baseId)
					* com.widedot.m6809.gamebuilder.plugin.direntry.DirEntryPlugin.BLOCK_SIZE;
			int nsector = (int) Math.ceil(size / 256.0);
			if (nsector > maxSectors) {
				maxSectors = nsector;
			}
		}
		out.append("loader.dir.buffer.SECTORS equ ").append(maxSectors)
		   .append(System.lineSeparator());

		out.append(ctx.dirLocations.trailer);

		String path = ctx.path + File.separator + "gen" + File.separator
				+ "directories" + File.separator + "locations.asm";
		Files.createDirectories(Paths.get(FileUtil.getDir(path)));
		Files.write(Paths.get(path), out.toString().getBytes());
		log.debug("directory locations table : {} entries -> {}", rows.size(), path);
	}

	/**
	 * The media's interleave, for the boot sector and the loader : the
	 * reading order (sclist) and the per-track skew, from the SAME Interleave
	 * the image is written with — three hand-kept copies of the table used to
	 * drift (07/09/2026).
	 */
	private static String interleaveBlock(Interleave il) {
		StringBuilder out = new StringBuilder();
		int period = il.skewPeriod();
		int mask = (16 % period == 0) ? 15 : 127;
		out.append("* The media's interleave : hardskip ").append(il.hardskip)
		   .append(", softskip ").append(il.softskip).append(", softskew ").append(il.softskew)
		   .append(System.lineSeparator());
		out.append("loader.interleave.HARDSKIP equ ").append(il.hardskip).append(System.lineSeparator());
		out.append("loader.interleave.SOFTSKIP equ ").append(il.softskip).append(System.lineSeparator());
		out.append("loader.interleave.SOFTSKEW equ ").append(il.softskew).append(System.lineSeparator());
		out.append("loader.interleave.SKEW_MASK equ ").append(mask).append(System.lineSeparator());
		out.append("* the physical sector numbers in reading order (logical sector 0, 1, 2 ...)")
		   .append(System.lineSeparator());
		out.append("_loader.interleave.sclist MACRO").append(System.lineSeparator());
		for (int i = 0; i < il.softMap.length; i += 4) {
			out.append("        fcb   ");
			for (int j = i; j < Math.min(i + 4, il.softMap.length); j++) {
				out.append(j > i ? "," : "").append(String.format("$%02x", il.softMap[j]));
			}
			out.append(System.lineSeparator());
		}
		out.append("        ENDM").append(System.lineSeparator());
		out.append("* sclist index of a track's first logical sector, indexed by track & SKEW_MASK")
		   .append(System.lineSeparator());
		out.append("_loader.interleave.skew MACRO").append(System.lineSeparator());
		for (int i = 0; i <= mask; i += 8) {
			out.append("        fcb   ");
			for (int j = i; j < Math.min(i + 8, mask + 1); j++) {
				out.append(j > i ? "," : "").append(il.skewIndex(j));
			}
			out.append(System.lineSeparator());
		}
		out.append("        ENDM").append(System.lineSeparator());

		return out.toString();
	}

	/** Walks the tree, replaying defaults/defines like the real pass nests them. */
	private static void walk(ImmutableNode node, BuildContext scope, List<Row> rows,
			int[] diskIndex, List<Interleave> interleaves) throws Exception {
		for (ImmutableNode child : node.getChildren()) {
			String kind = child.getNodeName();
			if ("default".equals(kind) || "define".equals(kind)) {
				Handlers.getDefault(kind).run(child, scope);
				continue;
			}
			if ("floppydisk".equals(kind)) {
				disk(child, scope.child(), rows, diskIndex[0]++, interleaves);
				continue;
			}
			walk(child, scope, rows, diskIndex, interleaves);
		}
	}

	private static void disk(ImmutableNode node, BuildContext scope, List<Row> rows,
			int diskIndex, List<Interleave> interleaves) throws Exception {
		String model = Attribute.getString(node, scope, "model");
		String storageFilename = scope.path + Attribute.getString(node, scope, "storage");
		Storage storage = new Storages(storageFilename).get(model);
		storage.overrideInterleave(Attribute.getIntegerOpt(node, scope, "hardskip"),
				Attribute.getIntegerOpt(node, scope, "softskip"),
				Attribute.getIntegerOpt(node, scope, "softskew"));
		interleaves.add(storage.interleave);

		for (ImmutableNode child : node.getChildren()) {
			String kind = child.getNodeName();
			if ("default".equals(kind) || "define".equals(kind)) {
				Handlers.getDefault(kind).run(child, scope);
				continue;
			}
			// section overrides apply in document order, as the real pass does
			if ("section".equals(kind)) {
				Section section = new Section(child, scope.defaults);
				storage.sections.put(section.name, section);
				continue;
			}
			if ("directory".equals(kind)) {
				Integer id = Attribute.getInteger(child, scope, "id");
				String sectionName = Attribute.getString(child, scope, "section");
				Section s = storage.sections.get(sectionName);
				if (s == null) {
					throw new Exception(scope.sources.locate(child) + ": directory " + id
							+ " references unknown section '" + sectionName + "'");
				}
				while (rows.size() <= id) {
					rows.add(null);
				}
				if (rows.get(id) != null) {
					throw new Exception(scope.sources.locate(child)
							+ ": directory id " + id + " is declared twice");
				}
				// sections declare sectors 1-based, the loader indexes its
				// interleave list 0-based (DIR_DEFAULT_SECTOR was $04-1)
				boolean colocate = Attribute.getBoolean(child, scope, "colocate", false);
				rows.set(id, new Row(diskIndex, s.face, s.track, s.sector - 1, sectionName,
						colocate));
				// reserve the directory's file ids and write its gensymbols
				// NOW : the id equates of one directory feed units that live
				// in another (a dependency cycle between title and stages),
				// so every equate file must exist before anything assembles
				com.widedot.m6809.gamebuilder.plugin.directory.DirectoryPlugin
						.reserve(child, scope.child());
			}
		}
	}
}
