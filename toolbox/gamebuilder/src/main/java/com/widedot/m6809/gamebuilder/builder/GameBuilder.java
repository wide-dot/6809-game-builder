package com.widedot.m6809.gamebuilder.builder;

import java.util.HashMap;

import com.widedot.m6809.gamebuilder.configuration.media.Directory;
import com.widedot.m6809.gamebuilder.configuration.media.File;
import com.widedot.m6809.gamebuilder.configuration.media.Media;
import com.widedot.m6809.gamebuilder.configuration.storage.Section;
import com.widedot.m6809.gamebuilder.configuration.storage.Storage;
import com.widedot.m6809.gamebuilder.configuration.target.Target;
import com.widedot.m6809.gamebuilder.directory.FloppyDiskDirectory;
import com.widedot.m6809.gamebuilder.storage.FdUtil;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class GameBuilder {

	Storage storage;
	FdUtil mediaData;
	HashMap<String, Section> sectionIndexes;
	
	public GameBuilder(Target target, String path) throws Exception {

		for (Media media : target.medias.mediaList) {

			storage = target.storages.get(media.storage);
			mediaData = new FdUtil(storage.faces, storage.tracks, storage.sectors, storage.sectorSize);
			sectionIndexes = new HashMap<String, Section>();

			log.debug("Process files with no associated directory.");
			for (File file : media.files) {
				writeFullSector(file);
			}

			log.debug("Process files with an associated directory.");
			for (Directory directory : media.directories) {
					
				// Directory can be engine specific or fat
				// TODO could have been a plugin
				if (directory.isFat()) {
					
					for (File file : directory.files) {
						log.debug("create directory (FAT)");
					}
					
					
				} else {
					
					for (File file : directory.files) {
						log.debug("create directory (custom)");
						FloppyDiskDirectory fdi = new FloppyDiskDirectory();
						fdi.compression = file.compression;
						
						Section section = getSection(file.section);
						fdi.face = section.face;
						fdi.track = section.track;
						fdi.sector = section.sector;
						int pos = 0, wBytes;
						boolean firstPass = true;
						int actualPos = mediaData.getIndex(section);
	
						log.debug("write data to media");
						while (pos < file.bin.length) {
							wBytes = mediaData.writeSector(file.bin, pos, section);
	
							if (firstPass) {
								if (wBytes < storage.sectorSize) {
									// if first sector is partial
									fdi.sFirstOffset = actualPos - wBytes;
									fdi.sFirstSize = wBytes;
								}
							} else {
								if (wBytes == storage.sectorSize) {
									// count full sectors
									fdi.sFullNbSectors++;
								} else {
									// if last sector is partial
									fdi.sLastSize = wBytes;
								}
							}
	
							mediaData.nextSector(section);
							pos = pos + wBytes;
						}
	
						log.debug("Add directory entry");
					}
	
					log.debug("Write directory to media");
				}
	
				log.debug("Write media to image file");
				mediaData.interleaveData(storage.interleave);
				mediaData.save(path + "/out"); // TODO parametre xml ?
			}
		}
	}
	
	public void writeFullSector(File file) throws Exception {
		log.debug("Write data to media.");
		Section section = getSection(file.section);
		int pos = 0;

		while (pos < file.bin.length) {
			mediaData.writeFullSector(file.bin, pos, section);
			mediaData.nextSector(section);
			pos = pos + storage.sectorSize;
		}
	}
	
	public Section getSection(String sectionName) {
		// if a new section is used, load it's definition
		if (!sectionIndexes.containsKey(sectionName)) {
			log.debug("Load section definition: {}", sectionName);
			Section sectionDefinition = storage.sections.get(sectionName);
			Section section = new Section(sectionDefinition);
			sectionIndexes.put(sectionName, section);
		}
		return sectionIndexes.get(sectionName);
	}
}
