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

	public SimpleTileMap(File paramFile, int inBitDepth, int outBitDepth, int outmult) throws Exception {
		
		System.out.println("Load "+paramFile.toString()+ " file ...");
	
		// check parameters
		if (inBitDepth <= 0 || outBitDepth <= 0) {
			throw new Exception ("input and output bit depth should be positive values.");
		}
		if (inBitDepth%8 != 0) {
			throw new Exception ("input bit depth should be multiple of 8.");
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
        
        // --------------------------------------------------------------------
        // load tilemap data
        // --------------------------------------------------------------------
        data = new byte[(width*height*outBitDepth+8-1)/8]; // ceil div by 8, thus add a byte when remaining bits
        
        int o = 0;
        int bcnt = 0;
        byte cbyte = 0;
        int inByteDepth = inBitDepth/8;
        byte[] tileId = new byte[inByteDepth];
        
	    // read each tile id
	    while(bufferedInputStream.available()>0){
	    	
	    	// if output byte depth is larger than input, pad with zero
	    	for (int pad = 0 ; pad < (outBitDepth>inBitDepth?outBitDepth-inBitDepth:0); pad++) {
	    		cbyte = (byte) (cbyte << 1);
	    		bcnt++;
	    		if (bcnt == 8) {
	    			data[o++] = cbyte;
	    			bcnt = 0;
	    	    	cbyte = 0;
	    		}
	    	}

	    	// input file is in little endian, reverse byte in a temporary array
	    	// and apply mult factor
	    	int val = 0;
	    	for (int i = 0; i < inByteDepth; i++) {
	    		val = ((bufferedInputStream.read() & 0xff) << i*8) + val;
	    	}
	    	
	    	val = val * outmult;
	    	
	    	for (int i = 0; i < inByteDepth; i++) {
	    		tileId [inByteDepth-1-i] = (byte)((val >> i*8) & 0xff);
	    	}
	    	
	    	// if output byte depth is smaller than input, skip bits
	    	int i = 0;
	    	int j = 0;
	    	int bcnt2 = 0;

	    	for (i = 0 ; i < inBitDepth-outBitDepth; i++) {
	    		bcnt2++;
	    		if (bcnt2 == 8) {
	    			j++;
	    			bcnt2 = 0;
	    		}
	    	}
	    	
	    	// copy bits
	    	while (i < inBitDepth) {
	    		bcnt++;
	    		bcnt2++;
	    		cbyte = (byte) ((cbyte << 1) + ((tileId[j] >> (8-bcnt2)) & 0b00000001));
	    		if (bcnt == 8) {
	    			data[o++] = cbyte;
	    			bcnt = 0;
	    		}
	    		if (bcnt2 == 8) {
	    			j++;
	    			bcnt2 = 0;
	    		}
	    		i++;
	    	}
	    	        
	    }
	    
	    // flush the bits to the left
	    if (bcnt > 0) {
	    	while (bcnt<8) {
	    		cbyte = (byte) (cbyte << 1);
	    		bcnt++;
	    		if (bcnt == 8) {
	    			data[o++] = cbyte;
	    			bcnt = 0;
	    		}
	    	}
	    }

	    bufferedInputStream.close();
        System.out.println("Done\n");
	}
}