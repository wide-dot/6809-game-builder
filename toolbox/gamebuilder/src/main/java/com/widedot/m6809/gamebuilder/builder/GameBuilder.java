package com.widedot.m6809.gamebuilder.builder;
 
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
 
import com.widedot.m6809.gamebuilder.configuration.Media;
import com.widedot.m6809.gamebuilder.configuration.LwAsm;
import com.widedot.m6809.gamebuilder.configuration.FloppyDiskIndex;
import com.widedot.m6809.gamebuilder.configuration.Ressource;
import com.widedot.m6809.gamebuilder.configuration.Section;
import com.widedot.m6809.gamebuilder.configuration.Storage;
import com.widedot.m6809.gamebuilder.configuration.Storages;
import com.widedot.m6809.gamebuilder.configuration.Index;
import com.widedot.m6809.gamebuilder.lwtools.LwAssembler;
import com.widedot.m6809.gamebuilder.lwtools.format.LwObject;
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
           
            // process lwasm commands that are inside indexes
            log.debug("process lwasms inside indexes");
            for (Index indexes : media.indexes) {
               
                // init starting point for index writing operations
                if (!sectionIndexes.containsKey(indexes.section)) {
                    Section sectionDefinition = storage.sections.get(indexes.section);
                    Section section = new Section(sectionDefinition);
                    sectionIndexes.put(indexes.section, section);
                }
               
                
                for (LwAsm lwasm : indexes.lwasms) {
                   
                    // init starting point for writing operations
                    if (!sectionIndexes.containsKey(lwasm.section)) {
                        Section sectionDefinition = storage.sections.get(lwasm.section);
                        Section section = new Section(sectionDefinition);
                        sectionIndexes.put(lwasm.section, section);
                    }
                   
                    // assemble ressources
                    int length = 0;
                    for (Ressource ressource : lwasm.ressources) {
                        ressource.computeBin(path, defines, lwasm.format);
                        length += ressource.bin.length;
                    }
                    
                    // concat binaries
                    log.debug("concat binaries");
                    byte[] data = new byte[length];
                    int i = 0;
                    for (Ressource ressource : lwasm.ressources) {
                    	System.arraycopy(ressource.bin, 0, data, i, ressource.bin.length);
                    	i += ressource.bin.length;
                    }
                                        
                    // create index
                    FloppyDiskIndex fdi = new FloppyDiskIndex();
                    fdi.compression = false;
                   
                    // compress data
                    if (!lwasm.codec.equals(LwAsm.NO_CODEC)) {
                        log.debug("compress data");
                        byte[] output = null;
                        int[] delta = { 0 };
                        output = new Compressor().compress(new Optimizer().optimize(data, 0, 32640, 4, false), data, 0, false, false, delta);
                        if (data.length > output.length) {
                            data = output;
                            fdi.compression = true;
                        } else if (delta[0] > FloppyDiskIndex.DELTA_SIZE) { // TODO adjust delta size limit
                            log.warn("lwasm {}: compressed data delta ({}) is too high, will be using uncompressed data", lwasm.symbol, delta[0]);
                        } else {
                            log.warn("lwasm {}: compressed data is bigger or equal, will be using uncompressed data", lwasm.symbol);
                        }
                        log.debug("Original size: {}, Packed size: {}, Delta: {}", data.length, output.length, delta[0]);
                    }
                   
                    // write data to media
                    log.debug("write data to media");
                    Section section = sectionIndexes.get(lwasm.section);
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
                   
                    // add lwasm to index
                    log.debug("add lwasm to index");
                }
               
                // write index to media
                log.debug("write index to media");
            }
           
            // process lwasm commands that are outside of indexes
            log.debug("process lwasms outside indexes");
            for (LwAsm lwasm : media.lwasms) {
            	
                // init starting point for writing operations
                if (!sectionIndexes.containsKey(lwasm.section)) {
                    Section sectionDefinition = storage.sections.get(lwasm.section);
                    Section section = new Section(sectionDefinition);
                    sectionIndexes.put(lwasm.section, section);
                }
            	
                for (Ressource ressource : lwasm.ressources) {
                    if (ressource.type == Ressource.ASM_INT) {
                    	ressource.computeBin(path, defines, lwasm.format);
 
	                    log.debug("write data to media");
	                    Section section = sectionIndexes.get(lwasm.section);
	                    int pos = 0;
	                   
	                    while (pos<ressource.bin.length) {
	                        mediaData.writeFullSector(ressource.bin, pos, section);                      
	                        mediaData.nextSector(section);
	                        pos = pos + storage.sectorSize;
	                    }
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
