package com.widedot.m6809.gamebuilder.plugin.floppydisk.storage;

import java.util.ArrayList;
import java.util.List;

import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Interleave;
import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Section;
import com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration.Storage;
import com.widedot.m6809.gamebuilder.spi.media.DirEntry;
import com.widedot.m6809.gamebuilder.spi.media.MediaDataInterface;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class FdUtil implements MediaDataInterface{
	public Storage storage;
    public boolean[] dataMask;
    private byte[] data;
    private byte[] interleavedData;
    private List<DirEntry> dirEntries;

    public FdUtil(Storage storage) {
        this.storage = storage;
        data = new byte[storage.segment.faces*storage.segment.tracks*storage.segment.sectors*storage.segment.sectorSize];
        dataMask = new boolean[data.length];
        dirEntries = new ArrayList<DirEntry>();
    }
    
	public byte[] write(String location, byte[] data) throws Exception {
		
		// retrieve dest section
		Section s = storage.sections.get(location);
		if (s == null) {
			String m = "Unknown Section: " + location;
			log.error(m);
			throw new Exception(m);
		}
		
		// write sectors
		int pos = 0;
		boolean first = true;
		
        //build directory entry
        byte[] direntry = new byte[6];
		direntry[0] = (byte) (((s.track & 0b01111111) << 1) | (s.face & 0x1));	// start track and face
		direntry[1] = (byte) s.sector;											// start sector nb
        direntry[5] = 0;														// nb of bytes in last sector (0: no partial end sector)
        
		while (pos < data.length) {
			int[] v = writeSector(data, pos, s);
			
			if (first) {
				if (v[1] == storage.segment.sectorSize) {
					
					// first written sector is full filled with data
					direntry[2] = 0;	// nb of bytes in first sector
					direntry[3] = 0;	// start offset in first sector
					direntry[4] = 1;	// full sectors
			        
				} else {
					
					// first written sector is partially written
					direntry[2] = (byte) v[1]; 	// nb of bytes in first sector
					direntry[3] = (byte) v[0]; 	// start offset in first sector
					direntry[4] = 0; 			// full sectors
				}
			} else {
				if (v[1] == storage.segment.sectorSize) { 
					direntry[4]++;		 		// inc full sectors
				} else {
					direntry[5] = (byte) v[1];	// nb of bytes in last sector, if partial		
				}
			}
			
			pos += v[1];				// moves ahead in source data 
			if (v[2]==0) nextSector(s);	// moves pointer to current free sector in common section
			first = false;
		}
		
        log.debug("write - track {}, face {}, start sector {}, nb bytes in first sector {}, offset in first sector {}, full sectors {}, nb bytes in last sector {}",
        		direntry[0] >> 1,
				direntry[0] & 0x1,
				direntry[1],
				direntry[2],
				direntry[3],
				direntry[4],
				direntry[5]);
        
        return direntry;
	}

	public byte[] getInterleavedData() throws Exception {
		if (interleavedData==null) {
			interleave();
		}
		return interleavedData;
	}    
	
	public void addDirEntry(DirEntry entry) throws Exception {
		dirEntries.add(entry);
	}

	public List<DirEntry> getDirEntries() throws Exception {
		return dirEntries;
	}

    public int[] writeSector(byte[] srcData, int srcIdx, Section section) throws Exception {
    	int[] ret = new int[3];
        int start = getIndex(section.face, section.track, section.sector);
        int end = start + storage.segment.sectorSize;
        int nbBytes = 0;
        
        // search for free space inside the sector
        int freePos;
        for (freePos = start; freePos < end; freePos++) {
            if (!dataMask[freePos]) break; 
        }
        
        // write to sector
        int i = freePos;
        while ((i < end) && (srcIdx < srcData.length)) {
            data[i] = srcData[srcIdx++];
            dataMask[i] = true;
            nbBytes++;
            i++;
        }

        ret[0] = freePos-start; // offset to written data
        ret[1] = nbBytes;       // nb of written bytes
        ret[2] = end-i;         // remaining bytes in sector
        return ret;
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
    
    public int getIndex(Section section) {
        return (section.face * 327680) + (section.track * 4096) + ((section.sector - 1) * 256);
    }
    
    public int getIndex(int face, int track, int sector) {
        return (face * 327680) + (track * 4096) + ((sector - 1) * 256);
    }

    private void interleave() {
        byte[] idata = new byte[data.length];

        // apply sector interleaving and face optimisation
        int pos = 0, s = 0;
        for (int f = 0; f < storage.segment.faces; f++) {
        	for (int t = 0; t < storage.segment.tracks; t++) {
                // apply skew based on track number
            	s = Interleave.getSoftIndex(storage.interleave.softMap, storage.interleave.hardMap[(t*storage.interleave.softskew)%storage.segment.sectors]);
            	
                // iterate n storage.segment.sectors
                for (int ns = 0; ns < storage.segment.sectors; ns++) {
                    System.arraycopy(data, pos, idata, getIndex(f, t, storage.interleave.softMap[s]), storage.segment.sectorSize);
                    pos += storage.segment.sectorSize;
                    s = (s+1)%storage.segment.sectors;
                }
            }
        }
        
        interleavedData = idata;
    }
	
}