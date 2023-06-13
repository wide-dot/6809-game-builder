package com.widedot.m6809.gamebuilder.configuration;

public class FloppyDiskIndex {
	
	public byte[] indexEntry;
	
	public boolean compression = false;
	public int face;
	public int track;
	public int sector;
	public int sFirstSize = 0;     // bytes in first sector
	public int sFirstOffset = 0;   // start offset in first sector (0: no sector)
	public int sFullNbSectors = 0; // full sectors to read
	public int sLastSize = 0;      // bytes in last sector (0: no sector)
	
	// options when compression is used
	public static final int DELTA_SIZE = 5;       // nb of bytes for safe in place decompression
	public int writeOffset = 0;                   // offset to write compressed data for in place decompression
	public byte[] endData = new byte[DELTA_SIZE]; // end data that can not be included in compressed data
	
	public FloppyDiskIndex() {
	}
	
	public byte[] computeIndexEntry() {
		
		int size = 7;
		
		if (compression) {
			size += 7;
		}
		
		indexEntry = new byte[size];

		// main
		indexEntry[0] = (byte) (compression?0b10000000:0);
		indexEntry[1] = (byte) (track*2+face%2);
		indexEntry[2] = (byte) sector;
		indexEntry[3] = (byte) sFirstSize;
		indexEntry[4] = (byte) sFirstOffset;
		indexEntry[5] = (byte) sFullNbSectors;
		indexEntry[6] = (byte) sLastSize;
		
		// compression specific
		indexEntry[7] = (byte) (writeOffset >> 8);
		indexEntry[8] = (byte) (writeOffset & 0xff);
		for (int i=0; i < endData.length; i++) {
			indexEntry[i+9] = endData[i];
		}
		
		return indexEntry;
	}
}
