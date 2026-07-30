package com.widedot.m6809.gamebuilder.plugin.sap.util;

import java.io.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import com.widedot.m6809.util.FileUtil;

// based on jteo code from Gilles Fetis

public class Sap {

	public static final int NB_DRIVE = 4;
	public static final int NB_SECT = 16;

	public static final int SAP_HEADER_SIZE = 66;
	public static final int SAP_SECTOR_META_SIZE = 6;
	public static final int SAP_FORMAT1 = 1;
	public static final int SAP_FORMAT2 = 2;

	public static final byte SAP_MAGIC_NUM = (byte) 0xB3;
	public static final int puktable[] = { 0x0000, 0x1081, 0x2102, 0x3183, 0x4204, 0x5285, 0x6306, 0x7387, 0x8408, 0x9489,
			0xa50a, 0xb58b, 0xc60c, 0xd68d, 0xe70e, 0xf78f };
	
	public static final String sapHeader = "SYSTEME D'ARCHIVAGE PUKALL S.A.P. (c) Alexandre PUKALL Avril 1998";
	
	private byte sapFile[][];
	private boolean usedDrive[];
	public int type;
	
	public Sap(byte[] data, int type) throws Exception {
		sapFile = new byte[NB_DRIVE][];
		usedDrive = new boolean[NB_DRIVE];
		this.type = type;
		
		// check SAP Type 
		if (type<1 || type>2)
			throw new Exception("SAP type can only be 1 or 2.");
		
		// check used data range in order to produce only the number of necessary sap files
		// the stride is the raw drive size, the same one Sector slices with :
		// driveSize includes the sap header and the per sector metadata, which
		// do not exist in the source image
		int rawDriveSize = SapType.nbTracks[type] * NB_SECT * SapType.sectorSize[type];
		for (int drive = 0; drive < NB_DRIVE; drive++) {
			for (int i = 0; i < rawDriveSize; i++) {
				if ((drive*rawDriveSize)+i >= data.length) {
					break;
				}
				if (data[(drive*rawDriveSize)+i] != 0) {
					usedDrive[drive] = true;
					break;
				}
			}
		}
		
		// create each sector for all drives and tracks
		for (int drive = 0; drive < NB_DRIVE; drive++) {
			
			if (usedDrive[drive]) {
				sapFile[drive] = new byte[SapType.driveSize[type]];
				setHeader(sapFile[drive]);
				
				for (short track = 0; track < SapType.nbTracks[type]; track++) {
					for (int sector = 0; sector < NB_SECT; sector++) {
						
						Sector a_SapSector = new Sector(type, drive, track, sector, data);
						int p = SAP_HEADER_SIZE + (track * SapType.trackSize[type]) + (sector * (SAP_SECTOR_META_SIZE + SapType.sectorSize[type]));

						sapFile[drive][p++] = a_SapSector.format;					
						sapFile[drive][p++] = a_SapSector.protection;
						sapFile[drive][p++] = a_SapSector.track;
						sapFile[drive][p++] = a_SapSector.sector;
						
						for (int i=0; i < SapType.sectorSize[type]; i++) {
							sapFile[drive][p++] = a_SapSector.data[i];
						}
						
						sapFile[drive][p++] = a_SapSector.crc1sect;
						sapFile[drive][p++] = a_SapSector.crc2sect;
						
					}
				}
				
			} else {
				sapFile[drive] = null;
			}
		}
	}

	/**
	 * @param drive drive index, 0 to NB_DRIVE-1
	 * @return the encoded sap image of that drive, null if the drive is unused
	 */
	public byte[] getSapFile(int drive) {
		return sapFile[drive];
	}

	private void setHeader(byte data[]) {
		data[0] = (byte) type;
		byte[] header = sapHeader.getBytes();
		for (int i=0; i<header.length; i++) {
			data[i+1] = header[i];
		}
	}

	public void write(String file) throws Exception {
		
		String ext = FileUtil.getExtension(file).get();
		String filebase = FileUtil.removeExtension(file);
		
		int usedDriveCount = 0;
		for (int drive = 0; drive < NB_DRIVE; drive++) {
			if (sapFile[drive] != null) usedDriveCount++;
		}

		for (int drive = 0; drive < NB_DRIVE; drive++) {
			if (sapFile[drive] != null) {
				
				Path outputFile;
				if (usedDriveCount == 1) {
					
					// only one drive, don't use file numbering
					outputFile = Paths.get(file);
					
				} else {
					
					// number every file : testing a single drive slot would make
					// two non contiguous drives write to the same name
					outputFile = Paths.get(filebase + "_" + drive + "." + ext);
				}
				
				try {
					Files.deleteIfExists(outputFile);
					Files.createFile(outputFile);
					Files.write(outputFile, sapFile[drive]);
				} catch (IOException e) {
					throw new Exception("Cannot write " + outputFile, e);
				}
			}
		}
	}
}