package com.widedot.m6809.gamebuilder.plugin.directory;

import java.io.File;
import com.widedot.m6809.gamebuilder.Handlers;
import com.widedot.m6809.gamebuilder.spi.BuildContext;
import java.io.FileWriter;
import java.nio.file.Files;
import java.nio.file.Paths;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.m6809.gamebuilder.spi.globals.FileIds;
import com.widedot.m6809.gamebuilder.plugin.direntry.DirEntryPlugin;
import com.widedot.m6809.gamebuilder.plugin.direntry.util.DirEntryDecoder;
import com.widedot.m6809.gamebuilder.plugin.pageset.PageSetPlugin;
import com.widedot.m6809.gamebuilder.plugin.scene.SceneCheck;
import com.widedot.m6809.gamebuilder.plugin.scene.SceneChecks;
import com.widedot.m6809.gamebuilder.plugin.scene.ScenePlugin;
import com.widedot.m6809.gamebuilder.spi.media.DirEntry;
import com.widedot.m6809.gamebuilder.spi.media.MediaDataInterface;
import com.widedot.m6809.gamebuilder.spi.media.MediaPluginInterface;
import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class DirectoryPlugin {
	
//	Directory Header (7 bytes)
//  -----------------------------------------------------------------------------------------------
//	[I] [D] [X] : [tag]
//	[0000 0000] : [disk id 0-255]
//	[0000 0000] : [nb of sectors to load for this index]
//	[0000 0000] [0000 0000] : [global file id of the first entry of this directory]
//	                          file ids are allocated continuously across all the
//	                          directories of a target, so that a file is identified
//	                          by its id alone at runtime ; the loader subtracts this
//	                          base to get the entry index inside this directory
	
//	Directory content
//  -----------------------------------------------------------------------------------------------
//  ...         : direntries

	
	public static void run(ImmutableNode node, BuildContext ctx, MediaDataInterface media) throws Exception {
    	
		log.debug("Processing directory ...");

		Integer id = Attribute.getInteger(node, ctx, "id");
		String section = Attribute.getString(node, ctx, "section");
		String genbinary = Attribute.getStringOpt(node, ctx, "genbinary");
	    String gensymbols = Attribute.getString(node, ctx, "gensymbols");

		// generate symbols file
		String gensymbolsPath = ctx.path + File.separator + gensymbols;
		Files.createDirectories(Paths.get(FileUtil.getDir(gensymbolsPath)));
		FileWriter writer = new FileWriter(gensymbolsPath);

		// file ids are global to the target : keep numbering where the
		// previous directory left off, and record the base in the header
		int baseId = ctx.fileIds.peek();
		int fileId = baseId;
		java.util.Set<String> directoryNames = new java.util.HashSet<String>();
		// id and block count of every entry : lets the scene generator emit
		// the compact %11 encoding when a list follows the id chain the
		// loader walks (id += blocks)
		java.util.Map<String, int[]> idBlocks = new java.util.HashMap<String, int[]>();
		// what each pageset's reservation-time packing produced, reused by the
		// emission : measuring twice would let the two disagree, which the
		// reserved==emitted assertion below would refuse
		java.util.Map<String, PageSetPlugin.Packing> packings =
				new java.util.HashMap<String, PageSetPlugin.Packing>();
		// packing assembles content, so it has to see the directory's own
		// <default>/<define> elements exactly as the emission will : replay
		// the pure configuration children into a scratch context as we walk
		BuildContext resCtx = ctx.child();
		for (ImmutableNode child : node.getChildren()) {
			String plugin = child.getNodeName();
			if (plugin.equals("default") || plugin.equals("define")) {
				Handlers.getDefault(plugin).run(child, resCtx);
				continue;
			}
			if (plugin.equals("pageset")) {
				// a pageset becomes one entry per FILLED page of its region :
				// ids are handed out here, so the set is measured and packed
				// here — the member count is the packing's result, and a scene
				// declared before its pageset finds the members already known
				PageSetPlugin.Packing packing = PageSetPlugin.pack(child, resCtx);
				int blocks = DirEntryPlugin.blockCount(packing.codec, packing.linkSection);
				for (com.widedot.m6809.gamebuilder.spi.globals.PageSets.Member member
						: packing.members) {
					writer.write(member.name + " equ " + fileId + System.lineSeparator());
					directoryNames.add(member.name);
					idBlocks.put(member.name, new int[] { fileId, blocks });
					fileId += blocks;
				}
				directoryNames.add(packing.name);
				ctx.pageSets.declare(packing.name, packing.members);
				packings.put(packing.name, packing);
				continue;
			}
			if (plugin.equals("file") || plugin.equals("scene")) {

				// resCtx, not ctx : the directory's own <default> elements are
				// replayed into it as this loop walks, and a defaulted attribute
				// that changes the block count (file.codec) must be seen here
				// exactly as the emission will see it
				String name = Attribute.getString(child, resCtx, "name");
				writer.write(name + " equ " + fileId + System.lineSeparator());
				directoryNames.add(name);

				// a literal attributed place is published next to the file id :
				// resident code that reaches a raw binary by page and address
				// (a scroll buffer, a bitmap) reads it from the same include it
				// already needs for the id — the value has one source, the
				// declaration. Arena and region places are not published : their
				// content is linkable, so references resolve through the
				// symbols, baked or load-time linked
				if (plugin.equals("file")) {
					com.widedot.m6809.gamebuilder.spi.globals.FilePlaces.Place place =
							ctx.filePlaces.get(name);
					if (place != null && place.page != null && place.address != null) {
						writer.write(name + ".page equ " + place.page
								+ System.lineSeparator());
						writer.write(name + ".address equ $"
								+ String.format("%04X", place.address)
								+ System.lineSeparator());
					}
				}

				int blocks;
				if (plugin.equals("file")) {
					String codec = DirEntryPlugin.effectiveCodec(
							Attribute.getStringOpt(child, resCtx, "codec"));
					String linkSection = Attribute.getStringOpt(child, resCtx, "linkdata");
					blocks = DirEntryPlugin.blockCount(codec, linkSection);
				} else {
					// a scene table is raw, uncompressed and carries no link data
					blocks = 1;
				}
				idBlocks.put(name, new int[] { fileId, blocks });
				fileId += blocks;
			}
		}
		writer.close();
		ctx.fileIds.next = fileId;
		log.debug("directory {} : file ids {} to {}", id, baseId, fileId-1);
		
		// instanciate local definitions
		// nested containers get their own defaults and defines
		BuildContext localCtx = ctx.child();

		// what each scene declared, verified once all the entries are built
		// and the uncompressed sizes are known
		java.util.List<SceneCheck> pendingScenes = new java.util.ArrayList<SceneCheck>();

		for (ImmutableNode child : node.getChildren()) {
			String plugin = child.getNodeName();

			// scenes live inside a directory only : they need its gensymbols
			// file for the id equates and its name set for reference checks
			if (plugin.equals("scene")) {
				log.debug("Running handler: {}", plugin);
				ScenePlugin.run(child, localCtx, media, gensymbols, directoryNames, idBlocks, pendingScenes);
				ctx.publish(localCtx);
				continue;
			}

			// pagesets too : their members are directory entries, packed when
			// the ids were reserved above — the emission reuses that packing
			if (plugin.equals("pageset")) {
				log.debug("Running handler: {}", plugin);
				PageSetPlugin.run(child, localCtx, media,
						packings.get(Attribute.getString(child, ctx, "name")));
				ctx.publish(localCtx);
				continue;
			}

			DefaultPluginInterface defaultHandler = Handlers.getDefault(plugin);
			MediaPluginInterface mediaHandler = Handlers.getMedia(plugin);

	        if (defaultHandler == null && mediaHandler == null) {
	        	throw new Exception("Element <" + plugin + "> is not valid here");
	        }
		    
	        if (defaultHandler != null) {
			    log.debug("Running handler: {}", plugin);
			    defaultHandler.run(child, localCtx);
				ctx.publish(localCtx);
	        }
	        
	        if (mediaHandler != null) {
			    log.debug("Running handler: {}", plugin);
			    mediaHandler.run(child, localCtx, media);
			    ctx.publish(localCtx);
	        }
    	}
		
		// every entry is built : verify what the scenes declared against the
		// real sizes. Checks are local to one scene — one composition must be
		// coherent in itself ; sequencing compositions belongs to the game
		// code, so nothing is checked across scenes.
		if (!pendingScenes.isEmpty()) {
			java.util.Map<String, Integer> sizes = new java.util.HashMap<String, Integer>();
			java.util.Map<String, java.util.Map<String, int[]>> pageSpans =
					new java.util.HashMap<String, java.util.Map<String, int[]>>();
			for (DirEntry entry : media.getDirEntries()) {
				sizes.put(entry.name, entry.length);
				if (!entry.pageSpans.isEmpty()) {
					pageSpans.put(entry.name, entry.pageSpans);
				}
			}
			java.util.List<String> sceneErrors = SceneChecks.verify(pendingScenes, sizes, pageSpans,
					ctx.regions.hasMeasures());
			if (!sceneErrors.isEmpty()) {
				throw new Exception("Invalid scene:\n  " + String.join("\n  ", sceneErrors));
			}

			// the same resolved loads, kept for the occupancy map : where each
			// scene lands and how much of every budget it really uses. The
			// last pass wins — the map survives the passes, re-recording
			// without forgetting made every load appear once per pass
			for (SceneCheck scene : pendingScenes) {
				ctx.ramMap.forget(scene.sceneName);
			}
			for (SceneCheck scene : pendingScenes) {
				for (SceneCheck.Load load : scene.loads) {
					if (load.kind == SceneCheck.Kind.EXPORT_ONLY) {
						continue;
					}
					Integer size = sizes.get(load.name);
					if (size == null) {
						continue;
					}
					ctx.ramMap.record(scene.sceneName, new com.widedot.m6809.gamebuilder.spi.globals.RamMap.Load(
							load.name, load.region, load.page, load.address, size));
				}
			}
		}

		// flush the entries' payloads to the media in FIRST-USE order : the
		// scenes, walked in declaration order, say which entry a game reads
		// first — its table, then its files in table order — so a scene's
		// sectors follow each other and its load never sends the head back
		// (the seek report prints that criterion). Entries no scene names
		// keep the declaration order, after the ranked ones. The 6 byte
		// location descriptors are patched into the entry blocks here, the
		// only part of an entry that depends on where the bytes land.
		java.util.LinkedHashSet<String> firstUse = new java.util.LinkedHashSet<String>();
		for (SceneCheck scene : pendingScenes) {
			firstUse.add(scene.sceneName);
			for (SceneCheck.Load load : scene.loads) {
				firstUse.add(load.name);
			}
		}
		java.util.Map<String, DirEntry> unranked = new java.util.LinkedHashMap<String, DirEntry>();
		for (DirEntry entry : media.getDirEntries()) {
			unranked.put(entry.name, entry);
		}
		java.util.List<DirEntry> flushOrder = new java.util.ArrayList<DirEntry>();
		for (String name : firstUse) {
			DirEntry ranked = unranked.remove(name);
			if (ranked != null) {
				flushOrder.add(ranked);
			}
		}
		flushOrder.addAll(unranked.values());
		for (DirEntry entry : flushOrder) {
			for (DirEntry.Pending pending : entry.pending) {
				byte[] location = media.cwrite(pending.section, pending.bytes, pending.name);
				System.arraycopy(location, 0, entry.data, pending.patchOffset, 6);
			}
			entry.pending.clear();
		}

		// compute directory size
		int size = 7;
		int emittedBlocks = 0;
		for (DirEntry entry : media.getDirEntries()) {
			size += entry.data.length;
			emittedBlocks += entry.data.length / DirEntryPlugin.BLOCK_SIZE;
		}

		// the ids handed out above are indexes into this very table : if the two
		// ever disagree, every file after the divergence is read at the wrong
		// offset by loader.dir.getFile
		int reservedBlocks = fileId - baseId;
		if (emittedBlocks != reservedBlocks) {
			throw new Exception("Directory " + id + " emitted " + emittedBlocks
					+ " entry blocks while " + reservedBlocks + " file ids were reserved");
		}
		
		// the header stores the directory length as a sector count on one byte
		int nsector = (int) Math.ceil(size/256.0);
		if (nsector > 255) {
			throw new Exception("Directory holds " + nsector + " sectors, only 255 can be described");
		}

		// set header data 
		byte[] bin = new byte[size];
		int i = 0;
		bin[i++] = 'I';
		bin[i++] = 'D';
		bin[i++] = 'X';
		bin[i++] = id.byteValue();
		bin[i++] = (byte) nsector;
		bin[i++] = (byte) ((baseId >> 8) & 0xff);
		bin[i++] = (byte) (baseId & 0xff);
		
		// set each file data
		for (DirEntry entry : media.getDirEntries()) {
			System.arraycopy(entry.data,0,bin,i,entry.data.length);
			i += entry.data.length;
		}

		// write whole directory to media
		media.write(section, bin, "directory " + id);
		
		// write whole directory to debug file
		if (genbinary != null) {
			genbinary = ctx.path + File.separator + genbinary;
			Files.createDirectories(Paths.get(FileUtil.getDir(genbinary)));
			Files.write(Paths.get(genbinary), bin);
			
			// write directory entries info to text file
			String textFile = genbinary + ".txt";
			FileWriter textWriter = new FileWriter(textFile);
			textWriter.write("Directory Entries Information" + System.lineSeparator());
			textWriter.write("=============================" + System.lineSeparator());
			textWriter.write("Directory ID: " + id + System.lineSeparator());
			textWriter.write("Base file ID: " + baseId + System.lineSeparator());
			textWriter.write("Directory structure size: " + size + " bytes" + System.lineSeparator());
			textWriter.write("Directory storage - Number of sectors to load: " + (byte) (Math.ceil(size/256.0)) + System.lineSeparator());
			textWriter.write(System.lineSeparator());
			
			int entryIndex = 0;
			for (DirEntry entry : media.getDirEntries()) {
				textWriter.write(System.lineSeparator());
				textWriter.write("=== Entry " + entryIndex + " [" + entry.name + "] ===" + System.lineSeparator());
				textWriter.write(DirEntryDecoder.analyzeEntry(entry));
				textWriter.write(System.lineSeparator());
				entryIndex++;
			}
			textWriter.close();
		}
		
		log.debug("End of processing directory");
	}

}
