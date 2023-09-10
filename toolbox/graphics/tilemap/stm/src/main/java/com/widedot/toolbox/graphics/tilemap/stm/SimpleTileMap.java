package com.widedot.toolbox.graphics.tilemap.stm;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;

/**
 * Simple tile map (*.stm) interpreter
 * https://www.cosmigo.com/promotion/docs/onlinehelp/TechnicalInfos.htm
 * Tile Mirroring option should be unchecked for both X and Y axis
 */

public class SimpleTileMap {
	
	public int width;   // tilemap width
	public int height;  // tilemap height
	public byte[] data; // tile indexes in output byte depth 

	public SimpleTileMap(File paramFile, int inByteDepth, int outByteDepth) throws Exception {
		
		System.out.println("Load "+paramFile.toString()+ " file ...");
	
		// check parameters
		if (inByteDepth <= 0 || outByteDepth <= 0) {
			throw new Exception ("input and output byte depth should be positive values.");
		}

		// read header
		byte[] header = new byte[8];
		BufferedInputStream  bufferedInputStream = new BufferedInputStream(new FileInputStream(paramFile));
		bufferedInputStream.read(header, 0, 8);
		
		// check file identifier
        if (header[0] != 0x53 || header[1] != 0x54  || header[2] != 0x4D || header[3] != 0x50) {
        	bufferedInputStream.close();
        	throw new Exception ("Simple tile map header not found.");
        }
        System.out.println("> STMP Header found");
        
        // load map size
        width = ((header[5] & 0xff) << 8) | (header[4] & 0xff);
        height = ((header[7] & 0xff) << 8) | (header[6] & 0xff);
        System.out.println("> Map Width: "+width+" Height: "+height+" Nb tiles: "+(width*height));
        
        // load tilemap data
        data = new byte[width*height*outByteDepth];
	    int outPos = 0;
    	int padBytes = (outByteDepth>inByteDepth?outByteDepth-inByteDepth:0);
    	int readOffset = (inByteDepth-1)-(inByteDepth>outByteDepth?inByteDepth-outByteDepth:0);
	    
	    // read each tile id
	    while(bufferedInputStream.available()>0){
	    	
	    	// if output byte depth is larger than input, pad with zero
	    	for (int pad = 0 ; pad < padBytes; pad++) {
	    		data[outPos++] = 0;
	    	}		    	
	    	
	    	// parse input file in little endian
	    	for (int offset = readOffset; offset >= 0; offset--) {
	    		data[outPos+offset] = (byte)bufferedInputStream.read(); // copy input data to output
	    	}
	    	outPos += readOffset+1;
    		bufferedInputStream.skip(inByteDepth-(readOffset+1));
	    }

	    bufferedInputStream.close();
        System.out.println("Done\n");
	}
	
	public int getDataLength() {
		int length = 0;
		if (data != null) {
			length = data.length;
		}
		return length;
	}	
}