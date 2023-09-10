package com.widedot.toolbox.graphics.engine;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class VerticalScrollTile {

	public VerticalScrollTile(String fileName){
		
		log.info("Engine vertical scroll tile generator ");
		log.info("Load "+fileName+ " file ...");
	
		try {
			
			Path path = Paths.get(fileName);
			byte[] raw = Files.readAllBytes(path);

			// contants
			int bpl   =   2; // byte per line
			int nbl   =  16; // nb of lines
			int tiles = 512; // total nb of tiles
			
			if (raw.length != bpl*nbl*tiles) {
				String m = "This tool only process tilesheet of 512 tiles (8x16)";
				log.error(m);
				throw new Exception(m);
			}
			
			byte[] out = new byte[raw.length];
			int tpos = 0;
			int j = 0;

			// split tileset by line, result will be a tileset for line 0, followed by tileser for line 1 ...
			// result is 16Ko of data with two 8ko block reversed
			
			// lines 0-7
			for (int t = 0; t < tiles; t++) {
				tpos = t*bpl*nbl;
				j = 0x2000+t*bpl;
				for (int i = 0; i < bpl*nbl/2; i++) {
					out[j]   = raw[tpos+i++];
					out[j+1] = raw[tpos+i];
					j += tiles*bpl;
				}
			}
			
			// lines 8-15
			for (int t = 0; t < tiles; t++) {
				tpos = t*bpl*nbl;
				j = t*bpl;
				for (int i = bpl*nbl/2; i < bpl*nbl; i++) {
					out[j]   = raw[tpos+i++];
					out[j+1] = raw[tpos+i];
					j += tiles*bpl;
				}
			}
			
			Path outpath = Paths.get(fileName+".vscrolltile");
			Files.write(outpath, out);

		} catch (Exception e) {
			e.printStackTrace();
			log.error(e.toString());
		}
		log.info("done.");
	}
	
}
