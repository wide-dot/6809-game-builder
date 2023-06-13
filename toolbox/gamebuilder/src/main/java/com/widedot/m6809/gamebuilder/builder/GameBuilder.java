package com.widedot.m6809.gamebuilder.builder;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import com.widedot.m6809.gamebuilder.configuration.Media;
import com.widedot.m6809.gamebuilder.configuration.FileGroup;
import com.widedot.m6809.gamebuilder.configuration.FloppyDiskIndex;
import com.widedot.m6809.gamebuilder.configuration.Ressource;
import com.widedot.m6809.gamebuilder.configuration.Section;
import com.widedot.m6809.gamebuilder.configuration.Storage;
import com.widedot.m6809.gamebuilder.configuration.Storages;
import com.widedot.m6809.gamebuilder.configuration.TableOfContent;
import com.widedot.m6809.gamebuilder.lwtools.LwAsm;
import com.widedot.m6809.gamebuilder.lwtools.LwObj;
import com.widedot.m6809.gamebuilder.lwtools.struct.LWSection;
import com.widedot.m6809.gamebuilder.storage.FdUtil;
import com.widedot.m6809.gamebuilder.zx0.Compressor;
import com.widedot.m6809.gamebuilder.zx0.Optimizer;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class GameBuilder {

	public GameBuilder(HashMap<String, String> defines, List<Media> mediaList, Storages storages, String path) throws Exception {
		for (Media media : mediaList) {
			
			Storage storage = storages.get(media.storage);
			FdUtil mediaData = new FdUtil(storage.faces, storage.tracks, storage.sectors, storage.sectorSize);
			HashMap<String, Section> sectionIndexes = new HashMap<String, Section>(); 
			
			// build filegroups that are inside tables of content
			for (TableOfContent tocs : media.tablesOfContent) {
				
				// init starting point for toc writing operations
				if (!sectionIndexes.containsKey(tocs.section)) {
					Section sectionDefinition = storage.sections.get(tocs.section);
					Section section = new Section(sectionDefinition);
					sectionIndexes.put(tocs.section, section);
				}
				
				for (FileGroup filegroup : tocs.fileGroups) {
					
					// init starting point for writing operations
					if (!sectionIndexes.containsKey(filegroup.section)) {
						Section sectionDefinition = storage.sections.get(filegroup.section);
						Section section = new Section(sectionDefinition);
						sectionIndexes.put(filegroup.section, section);
					}
					
					List<LwObj> objLst = new ArrayList<LwObj>();
					int dataSize = 0;
					for (Ressource ressource : filegroup.fileset.ressources) {
						if (ressource.type == Ressource.ASM_INT) {
							LwObj obj = LwAsm.makeObject(ressource.file, path, defines);
							objLst.add(obj);
							for (LWSection section : obj.secLst) {
								dataSize += section.code.length;
							}
						}
					}
					
					// concat all code sections for this filegroup
					log.debug("concat code sections");
					byte[] data = new byte[dataSize];
					int j=0;
					for (LwObj obj : objLst) {
						for (LWSection section : obj.secLst) {
							for (int i=0; i<section.code.length; i++) {
								data[j++] = section.code[i];
							}
						}
					}
					
					// create index
					FloppyDiskIndex fdi = new FloppyDiskIndex();
					fdi.compression = false;
					
					// compress data
					if (!filegroup.codec.equals(FileGroup.NO_CODEC)) {
						log.debug("compress data");
						byte[] output = null;
				        int[] delta = { 0 };
				        output = new Compressor().compress(new Optimizer().optimize(data, 0, 32640, 4, false), data, 0, false, false, delta);
				        if (data.length > output.length) {
				        	data = output;
				        	fdi.compression = true;
				        } else if (delta[0] > FloppyDiskIndex.DELTA_SIZE) { // TODO adjust delta size limit
				        	log.warn("filegroup {}: compressed data delta ({}) is too high, will be using uncompressed data", filegroup.name, delta[0]);
				        } else {
				        	log.warn("filegroup {}: compressed data is bigger or equal, will be using uncompressed data", filegroup.name);
				        }
				        log.debug("Original size: {}, Packed size: {}, Delta: {}", data.length, output.length, delta[0]);
					}
					
					// write data to media
					log.debug("write data to media");
					Section section = sectionIndexes.get(filegroup.section);
					fdi.face = section.face;
					fdi.track = section.track;
					fdi.sector = section.sector;
					int pos = 0, wBytes;
					boolean firstPass = true;
					int actualPos = mediaData.getIndex(section);
					
					while (pos<data.length) {
						wBytes=mediaData.writeSector(data, pos, section);
						
						if (firstPass) {
							if (wBytes<storage.sectorSize) {
								// if first sector is partial
								fdi.sFirstOffset = actualPos-wBytes;
								fdi.sFirstSize = wBytes;
							}
						} else {
							if (wBytes==storage.sectorSize) {
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
					
					// add filegroup to toc
					log.debug("add filegroup to toc");
				}
				
				// write toc to media
				log.debug("write toc to media");
			}
			
			// build filegroups that are outside of tables of content
			for (FileGroup fgs : media.fileGroups) {
				for (Ressource ressource : fgs.fileset.ressources) {
					if (ressource.type == Ressource.ASM_INT) {
						LwAsm.makeBinary(ressource.file, path, defines);
					}
				}
			}
			
			// write media to image file
			log.debug("write media to image file");
			mediaData.interleaveData(storage.interleave);
			mediaData.save(path+"/out"); // TODO parametre xml ?
		}
	}
	
}
