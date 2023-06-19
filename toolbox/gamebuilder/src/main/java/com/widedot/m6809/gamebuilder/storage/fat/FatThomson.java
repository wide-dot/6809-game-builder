package com.widedot.m6809.gamebuilder.storage.fat;

public class FatThomson {

	/* constants for the TO logical disk format */
	public static int TO_NSECTS               = 16;
	public static int TO_SECTOR_PER_BLOCK     = 8;

	public static int TO_SECTSIZE1            = 255;  /* not 256 */
	public static int TO_FAT_START1           = 257;
	public static int TO_NBLOCKS1             = 160;
	public static int TO_BLOCKSIZE1           = (TO_SECTOR_PER_BLOCK*TO_SECTSIZE1);
	public static int TO_FILESIZE_MAX1        = (TO_NBLOCKS1-2);
	public static int TO_DIR_START1           = 512;

	public static int TO_SECTSIZE2            = 127;  /* not 128 */
	public static int TO_FAT_START2           = 129;
	public static int TO_NBLOCKS2             = 80;
	public static int TO_BLOCKSIZE2           = (TO_SECTOR_PER_BLOCK*TO_SECTSIZE2);
	public static int TO_FILESIZE_MAX2        = (TO_NBLOCKS2-2);
	public static int TO_DIR_START2           = 256;

	public static int TO_FILLER_BYTE          = 0xE5;
	public static int TO_TAG_RESERVED         = 0xFE;
	public static int TO_TAG_FREE             = 0xFF;
	public static int TO_END_BLOCK_OFFSET     = 0xC0;

	public static int TO_DIRENTRY_LENGTH      = 32;
	public static int TO_NAME                 = 0;
	public static int TO_NAME_LENGTH          = 8;
	public static int TO_EXT                  = 8;
	public static int TO_EXT_LENGTH           = 3;
	public static int TO_FILE_TYPE            = 11;
	public static int TO_DATA_TYPE            = 12;
	public static int TO_FIRST_BLOCK          = 13;
	public static int TO_END_SIZE             = 14;
	public static int TO_COMMENT              = 16;
	public static int TO_COMMENT_LENGTH       = 8;
	public static int TO_DATE_DAY             = 24;
	public static int TO_DATE_MONTH           = 25;
	public static int TO_DATE_YEAR            = 26;
	public static int TO_CHG_MODE             = 30;
	public static int TO_CHG_CHECKSUM         = 31;

	public static int TO_DIRENTRY_PER_SECTOR1 = 8;
	public static int TO_NDIRENTRIES1         = (TO_NSECTS-2)*TO_DIRENTRY_PER_SECTOR1;

	public static int TO_DIRENTRY_PER_SECTOR2 = 4;
	public static int TO_NDIRENTRIES2         = (TO_NSECTS-2)*TO_DIRENTRY_PER_SECTOR2;

	public static int[] TO_SECTSIZE            = new int[]{TO_SECTSIZE1, TO_SECTSIZE2};
	public static int[] TO_FAT_START           = new int[]{TO_FAT_START1, TO_FAT_START2};
	public static int[] TO_NBLOCKS             = new int[]{TO_NBLOCKS1, TO_NBLOCKS2};
	public static int[] TO_BLOCKSIZE           = new int[]{TO_BLOCKSIZE1, TO_BLOCKSIZE2};
	public static int[] TO_FILESIZE_MAX        = new int[]{TO_FILESIZE_MAX1, TO_FILESIZE_MAX2};
	public static int[] TO_DIR_START           = new int[]{TO_DIR_START1, TO_DIR_START2};
	public static int[] TO_DIRENTRY_PER_SECTOR = new int[]{TO_DIRENTRY_PER_SECTOR1, TO_DIRENTRY_PER_SECTOR2};
	public static int[] TO_NDIRENTRIES         = new int[]{TO_NDIRENTRIES1, TO_NDIRENTRIES2};
	
	public static int THOMSON_SD = 0;
	public static int THOMSON_DD = 1;
	
	public int format;
	public byte[] track;
	
	public FatThomson (int f, int sectors, int sectorSize) {
		format = f;
		track = new byte[sectors*sectorSize];
	}
	
	public void AddFile(String filename) {
	}
	
}
