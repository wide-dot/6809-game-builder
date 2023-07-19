package com.widedot.m6809.gamebuilder.plugin.floppydisk.storage;

import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Section;
import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Storage;
import com.widedot.m6809.gamebuilder.spi.media.MediaDataInterface;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class FdUtil implements MediaDataInterface{
	public Storage storage;
    public boolean[] dataMask;
    private byte[] data;

    public FdUtil(Storage storage) {
        this.storage = storage;
        data = new byte[storage.segment.faces*storage.segment.tracks*storage.segment.sectors*storage.segment.sectorSize];
        dataMask = new boolean[data.length];
    }

    public int getIndex(Section section) {
        return (section.face * 327680) + (section.track * 4096) + ((section.sector - 1) * 256);
    }
    
    public int getIndex(int face, int track, int sector) {
        return (face * 327680) + (track * 4096) + ((sector - 1) * 256);
    }

    public void nextSector(Section section) throws Exception {
        section.sector++;
        if (section.sector-1==storage.segment.sectors) {
            section.sector=0;
            section.track++;
            if (section.track==storage.segment.tracks) {
                section.face++;
                if (section.face==storage.segment.faces) {
                    throw new Exception("No more space on media !");
                }
            }
        }
    }
    
    public int writeSector(byte[] srcData, int srcIdx, Section section) throws Exception {
        log.debug("Write face:{}, track: {}, sector: {}", section.face, section.track, section.sector);
        int start = getIndex(section.face, section.track, section.sector);
        int end = start + storage.segment.sectorSize;
        int nbBytes = 0;
        
        // search for free space inside the sector
        int freePos;
        for (freePos = start; freePos < end; freePos++) {
            if (!dataMask[freePos]) break; 
        }
        
        // write to sector
        for (int i = freePos; i < end; i++) {
            data[i] = srcData[srcIdx++];
            dataMask[i] = true;
            nbBytes++;
            
            if (srcIdx >= srcData.length) break; // break if no more data to write
        }
        
        if (nbBytes==0) {
            throw new Exception("Overlapping data at face:"+section.face+", track: "+section.face+", sector: "+section.face);
        }
        
        // return nb bytes written to sector
        return nbBytes;
    }
    
    public void writeFullSector(byte[] srcData, int srcIdx, Section section) throws Exception {
        log.debug("Write full sector, face:{}, track: {}, sector: {}", section.face, section.track, section.sector);
        int start = getIndex(section.face, section.track, section.sector);
        int end = start + storage.segment.sectorSize;
        
        // check that sector is empty
        for (int i = 0; i < storage.segment.sectorSize; i++) {
            if (dataMask[i]) {
                throw new Exception("Overlapping data at face:"+section.face+", track: "+section.face+", sector: "+section.face);
            }
        }
        
        // write to sector
        for (int i = start; i < end; i++) {
            data[i] = srcData[srcIdx++];
            dataMask[i] = true;
            
            if (srcIdx >= srcData.length) break; // break if no more data to write
        }
    }

    public void interleave() {
        byte[] idata = new byte[data.length];
        boolean[] slot = new boolean[data.length];

        // apply sector interleaving and face optimisation
        int pos = 0, s = 0;
        for (int t = 0; t < storage.segment.tracks; t++) {
            for (int f = 0; f < storage.segment.faces; f++) {

                // init mask array, used to know already loaded sector indexes
                for (int i = 0; i < storage.segment.sectors; i++) {slot[i]=false;}

                // iterate n storage.segment.sectors
                for (int ns = 0; ns < storage.segment.sectors; ns++) {

                    // skip already written sector id
                	s = s%storage.segment.sectors;
                    while (slot[s]) {s = (s+1)%storage.segment.sectors;}
                    System.arraycopy(data, pos, idata, getIndex(f, t, storage.interleave.softMap[s]), storage.segment.sectorSize);
                    pos += storage.segment.sectorSize;
                    slot[s] = true;

                    // sector change, apply skip
                    s += storage.interleave.softskip;
                }
            }
            
            // track change, apply skew
            s = s + storage.interleave.softskew - storage.interleave.softskip;
        }
        
        data = idata;
    }
    
	public void write(String location, byte[] data) throws Exception {
		Section s = storage.sections.get(location);
		if (s == null) {
			String m = "Unknown Section: " + location;
			log.error(m);
			throw new Exception(m);
		}
		writeSector(data, 0, s);
	}

	public byte[] getBytes() throws Exception {
		return data;
	}
	
}