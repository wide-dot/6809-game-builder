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
			int bpl   =   2;      // bytes per line
			int nbl   =  16;      // nb of lines
			int bpt   = bpl*nbl ; // bytes per tile
			int tiles = 512;      // total nb of tiles
			
			if (raw.length != bpl*nbl*tiles) {
				String m = "This tool only process tilesheet of 512 tiles (8x16)";
				log.error(m);
				throw new Exception(m);
			}
			
			byte[] out = new byte[raw.length];
			int tpos = 0, lpos = 0;
			int j = 0;

			// split tileset by line, result will be a tileset for line 0, followed by tileset for line 1 ...
			// result is 16Ko of data with two 8ko block reversed
			
			// lines 8-15
			for (int l = 8; l < 16; l++) {
				lpos = l*bpl;
				for (int t = 0; t < tiles; t++) {
					tpos = t*bpt;
					out[j++] = raw[tpos+lpos];
					out[j++] = raw[tpos+lpos+1];
				}
			}

			// lines 0-7
			for (int l = 0; l < 8; l++) {
				lpos = l*bpl;
				for (int t = 0; t < tiles; t++) {
					tpos = t*bpt;
					out[j++] = raw[tpos+lpos];
					out[j++] = raw[tpos+lpos+1];
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
