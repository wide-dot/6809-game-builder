package com.widedot.toolbox.graphics.engine;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class VerticalScrollTile {
	
	private final int MAX_FILE_SIZE = 0x4000;

	public VerticalScrollTile(String fileName){
		
		log.info("Engine vertical scroll tile generator ");
		log.info("Load "+fileName+ " file ...");
	
		try {
			
			Path path = Paths.get(fileName);
			byte[] raw = Files.readAllBytes(path);

			// contants
			int bpl   =   2;      // bytes per line
			int nbl   =  16;      // nb of lines
			int bpt   = bpl*nbl ; // bytes per tile
			
			if (raw.length%(bpl*nbl)!=0) {
				String m = "This tool only process tilesheet of 8x16 tiles !";
				log.error(m);
				throw new Exception(m);
			}

			int tiles = raw.length/(bpl*nbl);      // total nb of tiles
			
			if (tiles>2048) {
				String m = "This tool only process tilesheet of 2048 tiles max !";
				log.error(m);
				throw new Exception(m);
			}
			
			log.info("Nb Tiles: "+tiles);
			
			byte[] out = new byte[MAX_FILE_SIZE];
			int tpos = 0, lpos = 0;
			int j = 0;
			int filenum = 0;

			// split tileset by lines, result will be a tileset for each lines
			// result is maxed to 16Ko of data with two 8ko block reversed
			
			for (int l = 0; l < 16; l++) {
				
				// set tilset
				lpos = l*bpl;
				for (int t = 0; t < tiles; t++) {
					tpos = t*bpt;
					out[j++] = raw[tpos+lpos];
					out[j++] = raw[tpos+lpos+1];
				}
				
				if (j+tiles*bpl >= MAX_FILE_SIZE || l == 15) {
					
					// clear pad bytes
					while (j < MAX_FILE_SIZE) out[j++] = 0;
					
					// reverse 8Ko blocks
					byte tmp = 0;
					int k = 0;
					for (j = 0; j < MAX_FILE_SIZE/2; j++) {
						tmp = out[j];
						k = j+MAX_FILE_SIZE/2;
						out[j] = out[k];
						out[k] = tmp;
					}
					
					// flush file
					Path outpath = Paths.get(fileName+"."+tiles+"."+filenum+".vscrolltile");
					Files.write(outpath, out);
					j = 0;
					filenum++;
				}
			}
			
		} catch (Exception e) {
			e.printStackTrace();
			log.error(e.toString());
		}
		log.info("done.");
	}
	
}
