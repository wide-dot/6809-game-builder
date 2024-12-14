package com.widedot.toolbox.mea8000;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class MeaLoader {
	
	public MeaLoader() {
	}
	
	public static ArrayList<MeaContainer> load(String pathName) {
		
		log.info("mea file: {}", pathName);
		
		ArrayList<MeaContainer> meaContainers = new ArrayList<MeaContainer>();
		Path path = Paths.get(pathName);
		byte[] bytes;
		try {
			bytes = Files.readAllBytes(path);

			// read multiple stream
			int i=0, length=0;
			while (i<bytes.length-3) {
				
				MeaContainer meaContainer = new MeaContainer();
				
				// read header
				i=0;
				length = ((bytes[i++] & 0xff) << 8) | // data length including this header
						  (bytes[i++] & 0xff);
				i++;                                  // unused byte
				int pitch=(bytes[i++] * 2) & 0xff;    // unsigned int pitch/2
				log.info("Chunk header length: {} pitch: {}", length, pitch);
				
				// read data chunks
				while (i<length-3) {
					meaContainer.frames.add(Mea8000Decoder.decodeFrame(bytes, i, pitch));
					pitch = meaContainer.frames.get(meaContainer.frames.size()-1).pitch;
					i += 4;
				}
				
				meaContainer.compute();
				meaContainers.add(meaContainer);
			}
			
		} catch (IOException e) {
			e.printStackTrace();
			return null;
		}
				
		return meaContainers;
	};
}
