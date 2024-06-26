package com.widedot.toolbox.audio.pcm;

import java.io.File;
import java.nio.file.Files;

/**
 * Pcm converter
 */

public class Pcm {
	
	public byte[] data;

	public Pcm(File file) throws Exception {
		
		System.out.println("Load "+file.toString()+ " file ...");
		data = Files.readAllBytes(file.toPath());
	}
	
	public byte[] to6Bit() {
		
		System.out.println("Convert 8bit sample to 6bit ...");
		byte[] outData = new byte[data.length];
		int i;
	    for (i=0; i<data.length; i++) {
        	outData[i] = (byte) ((data[i] & 0xff) >> 2);
        }
	    
	    // end marker
	    outData[i-1] = (byte) ((outData[i-1] & 0xff) | 0x80);
	    
	    // todo : do not keep identical samples at the end of file
	    // todo : always set final output to x00 (centered wave signal)
	    
		return outData;
	}
}