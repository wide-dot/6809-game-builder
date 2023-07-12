package com.widedot.m6809.gamebuilder.builder;

import com.widedot.m6809.gamebuilder.configuration.target.Target;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class GameBuilder {

//	Storage storage;
//	FdUtil mediaData;
//	HashMap<String, Section> sectionIndexes;
	
	// n'est plus utilisé !!!!
	
	public GameBuilder(Target target, String path) throws Exception {

//		for (Media media : target.medias.mediaList) {
//
//			//storage = target.storages.get(media.storage);
//			mediaData = new FdUtil(storage.faces, storage.tracks, storage.sectors, storage.sectorSize);
//			sectionIndexes = new HashMap<String, Section>();
//
//			log.debug("Process files (no directory) ...");
//			for (File file : media.files) {
//				log.debug("Write file to section: {}", file.section);
//				writeFullSector(file);
//			}
//
//			log.debug("End of Process files (no directory)");
//			
//			log.debug("Process files (directory) ...");
//			for (Directory directory : media.directories) {
//					
//				// Directory can be engine specific or fat
//				// TODO could have been a plugin
//				if (directory.isFat()) {
//					
//					log.debug("FAT - Write dir entry to diskname: {}", directory.diskName);
//					for (File file : directory.files) {
//						log.debug("filename: {}", file.name);
//					}
//					
//				} else {
//
//					log.debug("CUSTOM - Write dir entry to diskname: {}", directory.diskName);
//					for (File file : directory.files) {
//						log.debug("filename: {}", file.name);
//						FloppyDiskDirectory fdi = new FloppyDiskDirectory();
//						fdi.compression = file.compression;
//						
//						Section section = getSection(file.section);
//						fdi.face = section.face;
//						fdi.track = section.track;
//						fdi.sector = section.sector;
//						int pos = 0, wBytes;
//						boolean firstPass = true;
//						int actualPos = mediaData.getIndex(section);
//	
//						log.debug("write data to media");
//						while (pos < file.bin.length) {
//							wBytes = mediaData.writeSector(file.bin, pos, section);
//	
//							if (firstPass) {
//								if (wBytes < storage.sectorSize) {
//									// if first sector is partial
//									fdi.sFirstOffset = actualPos - wBytes;
//									fdi.sFirstSize = wBytes;
//								}
//							} else {
//								if (wBytes == storage.sectorSize) {
//									// count full sectors
//									fdi.sFullNbSectors++;
//								} else {
//									// if last sector is partial
//									fdi.sLastSize = wBytes;
//								}
//							}
//	
//							mediaData.nextSector(section);
//							pos = pos + wBytes;
//						}
//	
//						log.debug("Add directory entry");
//					}
//	
//					log.debug("Write directory to media");
//				}
//			}	
//			
//			log.debug("End of Process files (directory)");
//			
//			log.debug("Write media to image file");
//			mediaData.interleaveData(storage.interleave);
//			mediaData.save(path + "/out"); // TODO parametre xml ?
//		}
	}
	
//	public void writeFullSector(File file) throws Exception {
//		
//		Section section = getSection(file.section);
//		int pos = 0;
//		
//		log.debug("Write data to media.");
//		while (pos < file.bin.length) {
//			mediaData.writeFullSector(file.bin, pos, section);
//			mediaData.nextSector(section);
//			pos = pos + storage.sectorSize;
//		}
//	}
//	
//	public Section getSection(String sectionName) {
//
//		if (!sectionIndexes.containsKey(sectionName)) {
//			log.debug("Load section definition: {}", sectionName);
//			Section sectionDefinition = storage.sections.get(sectionName);
//			Section section = new Section(sectionDefinition);
//			sectionIndexes.put(sectionName, section);
//		}
//		return sectionIndexes.get(sectionName);
//	}
}
