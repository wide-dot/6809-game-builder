package com.widedot.toolbox.graphics.engine;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class VerticalScroll {

	public VerticalScroll(String fileName){
		
		log.info("Engine vertical scroll generator ");
		log.info("Load "+fileName+ " file ...");
	
		try {
			
			byte ldd = (byte) 0xCC;
			byte ldx = (byte) 0x8E;
			byte[] ldy = {(byte) 0x10, (byte) 0x8E};
			byte ldu = (byte) 0xCE;
			byte[] pshs = {(byte) 0x34, (byte) 0x76};
			
			Path path = Paths.get(fileName);
			byte[] raw = Files.readAllBytes(path);
			
			byte[] out = new byte[raw.length+(raw.length/8)*7]; // add 7 bytes for instructions to each 8 bytes of data
			int i = raw.length-8, k = 0;
			
			while (i>=0) {
				out[k++] = ldd;
				out[k++] = raw[i];
				out[k++] = raw[i+1];
				out[k++] = ldx;
				out[k++] = raw[i+2];
				out[k++] = raw[i+3];
				out[k++] = ldy[0];
				out[k++] = ldy[1];
				out[k++] = raw[i+4];
				out[k++] = raw[i+5];
				out[k++] = ldu;
				out[k++] = raw[i+6];
				out[k++] = raw[i+7];
				out[k++] = pshs[0];
				out[k++] = pshs[1];
				i = i - 8;
			}
			
			Path outpath = Paths.get(fileName+".vscroll");
			Files.write(outpath, out);

		} catch (Exception e) {
			e.printStackTrace();
			log.error(e.toString());
		}
		log.info("done.");
	}
	
}
