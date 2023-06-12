package com.widedot.m6809.gamebuilder.storage;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import com.widedot.m6809.gamebuilder.configuration.Section;
import com.widedot.m6809.gamebuilder.storage.sap.Sap;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class FdUtil {
	public int faces;
	public int tracks;
	public int sectors;
	public int sectorSize;
	public boolean[] dataMask;
	private byte[] data;

	public FdUtil(int faces, int tracks, int sectors, int sectorSize) {
		this.faces = faces;
		this.tracks = tracks;
		this.sectors = sectors;
		this.sectorSize = sectorSize;
		data = new byte[faces*tracks*sectors*sectorSize];
		dataMask = new boolean[data.length];
	}

	public int getIndex(int face, int track, int sector) throws Exception {
		if (face < 0 || face > 3 || track < 0 || track > 79 || sector < 1 || sector > 16) {
			log.debug("face (0-3):" + face + " track (0-79):" + track + " sector (1-16):" + sector);
			throw new Exception ("Incorrect value for face, track or sector !");
		}
		return (face * 327680) + (track * 4096) + ((sector - 1) * 256);
	}

	public void nextSector(Section section) throws Exception {
		section.sector++;
		if (section.sector-1==sectors) {
			section.sector=0;
			section.track++;
			if (section.track==tracks) {
				section.face++;
				if (section.face==faces) {
					throw new Exception("No more space on media !");
				}
			}
		}
	}
	
	public int writeSector(byte[] srcData, int srcIdx, Section section) throws Exception {
		log.debug("Write face:{}, track: {}, sector: {}", section.face, section.track, section.sector);
		int start = getIndex(section.face, section.track, section.sector);
		int end = start + sectorSize;
		int nbBytes = 0;
		
		// search for free space inside the sector
		int freePos;
		for (freePos = start; freePos < end; freePos++) {
			if (!dataMask[freePos]) break; 
		}
		
		// write to sector
		for (int i = freePos; i < end; i++) {
			data[i] = srcData[srcIdx++];
			dataMask[i] = true;
			nbBytes++;
			
			if (srcIdx >= srcData.length) break; // break if no more data to write
		}
		
		// return nb bytes written to sector
		return nbBytes;
	}

	public void save(String outputFileName) {
		Path outputFile = Paths.get(outputFileName + ".fd");
		try {
			Files.deleteIfExists(outputFile);
			Files.createFile(outputFile);
			Files.write(outputFile, data);
		} catch (IOException e) {
			e.printStackTrace();
		}
	}

	public void saveToSd(String outputFileName) {
		final byte[] sdBytes = new byte[0x140000];

		for (int ifd = 0, isd = 0; ifd < data.length; ifd++) {
			sdBytes[isd] = data[ifd];
			isd++;
			
			// fill with 256x(0xFF) each 256 bytes
			if ((ifd + 1) % 256 == 0)
				for (int i = 0; i < 256; i++)
					sdBytes[isd++] = (byte) 0xFF;
		}

		Path outputFile = Paths.get(outputFileName + ".sd");
		try {
			Files.deleteIfExists(outputFile);
			Files.createFile(outputFile);
			Files.write(outputFile, sdBytes);
		} catch (IOException e) {
			e.printStackTrace();
		}
	}

	public void saveToSap(String outputDiskName) throws Exception {
		Sap sap = new Sap(data, Sap.SAP_FORMAT1);
		sap.write(outputDiskName);
	}

}