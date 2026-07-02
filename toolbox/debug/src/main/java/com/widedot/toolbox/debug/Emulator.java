package com.widedot.toolbox.debug;

import com.sun.jna.Memory;
import com.widedot.toolbox.debug.types.Data;
import com.widedot.toolbox.debug.types.Watch;

public class Emulator {
	// matched as a substring of the process name/path: covers both the Windows
	// "dcmoto_*.exe" and the macOS-under-Wine "dcmoto-64_*.exe".
	public static final String processName= "dcmoto";
	public static int pid = 0;

	// pixels représentant la première ligne du logo TO de l'écran de démarrage du TO8 en mémoire vidéo
	public static byte[] key = new byte[]{0x00, 0x7F, (byte) 0xFF, (byte) 0xFF, (byte) 0xFF, (byte) 0xFF, (byte) 0xFF, (byte) 0xFE, 0x00, 0x00, (byte) 0xFF, (byte) 0xFF, (byte) 0xFF, (byte) 0xFF, (byte) 0xFF, 0x00};
	public static int keypos = 0x2190;

	public static long ramAddress = 0;

	public static long portAddress = 0;  // port[0x40]   ports d'entrees/sorties
	public static long ddrAddress = 0;   // ddr[0x40]    registres de direction des PIA 6821
	public static long plineAddress = 0; // pline[0x40]  peripheral input-control lines des PIA 6821
	public static long carAddress = 0;   // car[0x20000] espace cartouche 8x16K (pour OS-9)
	public static long x7daAddress = 0;  // x7da[0x20]   LEGACY fixed palette offset (ram+0x805C0);
	                                     // no longer valid on recent DCMOTO builds. Kept for reference.

	// ===========================================================================
	// Palette location (version-robust, no build-dependent address)
	//
	// DCMOTO stores the palette at a build-specific offset AND in different byte
	// layouts between versions, so we LOCATE it by scanning memory for the known
	// TO8 SYSTEM palette values (present on the boot / home screen, exactly like
	// the boot-logo signature that anchors ramAddress). We search for the system
	// palette as two byte strings - the two layouts observed across DCMOTO builds:
	//
	//   PAL_NIBBLE : legacy raw TO8 format, 16 colours x 2 bytes.
	//                even byte = (green<<4)|red, odd byte low nibble = blue
	//                (high nibble = marking/M bit, ignored). Decoded via ThomsonRGB.
	//                Historically at the FIXED offset ram+0x805C0 (see x7daAddress)
	//                on the DCMOTO builds this tool originally targeted (Windows).
	//
	//   PAL_BGRX   : recent format (seen in dcmoto-64_20260114), 16 colours x 4
	//                bytes = already-decoded 8-bit RGB stored as B,G,R,00. Used as-is.
	//
	// ---------------------------------------------------------------------------
	// VERIFIED under Windows (dcmoto_20250515, 2026-07-02): searchPaletteAddress()
	//   found the system palette as PAL_NIBBLE at the legacy ram+0x805C0. The 32
	//   captured bytes confirmed PAL_NIBBLE_PATTERN exactly on the even bytes and
	//   the blue low-nibble; the odd-byte HIGH nibble is the M/marking bit (=1 on
	//   colours, 0 for black), which PAL_NIBBLE_MASK correctly masks out. Pattern
	//   below now holds the authoritative captured bytes; keep the mask.
	//   Reference system colours (R,G,B 8-bit), in palette index order 0..15:
	//     000000 FF0000 00FF00 FFFF00 0000FF FF00FF 00FFFF EBFAFA
	//     C2FAFA DB8F8F 8FDB8F DBDB8F 007A9E DB8FDB CCFAE3 E3C200
	// ===========================================================================

	public static final int PAL_NONE = 0, PAL_NIBBLE = 1, PAL_BGRX = 2;
	public static int paletteFormat = PAL_NONE;
	public static long paletteAddress = 0;

	// PAL_BGRX: verified from dcmoto-64_20260114 memory (B,G,R,00 per colour).
	public static final byte[] PAL_BGRX_PATTERN = {
		0x00,0x00,0x00,0x00,             0x00,0x00,(byte)0xFF,0x00,       0x00,(byte)0xFF,0x00,0x00,       0x00,(byte)0xFF,(byte)0xFF,0x00,
		(byte)0xFF,0x00,0x00,0x00,       (byte)0xFF,0x00,(byte)0xFF,0x00, (byte)0xFF,(byte)0xFF,0x00,0x00, (byte)0xFA,(byte)0xFA,(byte)0xEB,0x00,
		(byte)0xFA,(byte)0xFA,(byte)0xC2,0x00, (byte)0x8F,(byte)0x8F,(byte)0xDB,0x00, (byte)0x8F,(byte)0xDB,(byte)0x8F,0x00, (byte)0x8F,(byte)0xDB,(byte)0xDB,0x00,
		(byte)0x9E,(byte)0x7A,0x00,0x00, (byte)0xDB,(byte)0x8F,(byte)0xDB,0x00, (byte)0xE3,(byte)0xFA,(byte)0xCC,0x00, 0x00,(byte)0xC2,(byte)0xE3,0x00
	};

	// PAL_NIBBLE: VERIFIED from dcmoto_20250515 memory (ram+0x805C0). even=(G<<4)|R,
	// odd = (M<<4)|B (M/marking bit = 1 on colours, 0 for black; masked out below).
	public static final byte[] PAL_NIBBLE_PATTERN = {
		0x00,0x00, 0x0F,0x10, (byte)0xF0,0x10, (byte)0xFF,0x10, 0x00,0x1F, 0x0F,0x1F, (byte)0xF0,0x1F, (byte)0xEC,0x1E,
		(byte)0xE7,0x1E, 0x3A,0x13, (byte)0xA3,0x13, (byte)0xAA,0x13, 0x20,0x14, 0x3A,0x1A, (byte)0xE8,0x1B, 0x7B,0x10
	};
	// mask: even byte full (green/red), odd byte low nibble only (blue; ignore M/marking bit)
	public static final byte[] PAL_NIBBLE_MASK = {
		(byte)0xFF,0x0F, (byte)0xFF,0x0F, (byte)0xFF,0x0F, (byte)0xFF,0x0F, (byte)0xFF,0x0F, (byte)0xFF,0x0F, (byte)0xFF,0x0F, (byte)0xFF,0x0F,
		(byte)0xFF,0x0F, (byte)0xFF,0x0F, (byte)0xFF,0x0F, (byte)0xFF,0x0F, (byte)0xFF,0x0F, (byte)0xFF,0x0F, (byte)0xFF,0x0F, (byte)0xFF,0x0F
	};

	// Locate the palette by scanning for the system palette in either known layout.
	// Run this while the TO8 system palette is on screen (boot / home screen).
	public static void searchPaletteAddress() {
		long a = OS.findBytes(PAL_BGRX_PATTERN, null);
		if (a != 0) { paletteAddress = a; paletteFormat = PAL_BGRX; return; }
		a = OS.findBytes(PAL_NIBBLE_PATTERN, PAL_NIBBLE_MASK);
		if (a != 0) { paletteAddress = a; paletteFormat = PAL_NIBBLE; return; }
		paletteAddress = 0; paletteFormat = PAL_NONE;
	}

    public static Integer get(Watch w)
    {
 	   	if (w.address.value == null) return null;
    	int address = w.address.value.get() + w.offset.getValue();
    	int page = w.page.value.get();
    	
    	if (address >= 0x6000 && address < 0xA000) {
    		page = 1;
    		address -= 0x6000;
    	}
    	
    	if (address >= 0x4000) return null; // TODO gerer le montage des pages dans les espaces RAM et ROM

    	long processAddr = ramAddress + page*0x4000 + address;
        Memory x_velMem = OS.readMemory(processAddr, Data.byteLen.get(w.value.type));
        
        Integer result = 0;
        int nbBytes = Data.byteLen.get(w.value.type);
        for (int i = 0; i < nbBytes; i++) {
        	result += (x_velMem.getByte(i) & 0xff) << (8*(nbBytes-1-i)) ;
        }
        
		return result;
    } 
    
    public static Long getAbsoluteAddress(int page, String addrStr)
    {
 	   	if (addrStr == null) return null;
 	   	int address = Integer.parseInt(addrStr, 16);
    	
    	return getAbsoluteAddress(page, address);
    } 
    
    public static long getAbsoluteAddress(int page, Integer address)
    {
 	   	if (address == null) return 0L;
    	
    	if (address >= 0x6000 && address < 0xA000) {
    		page = 1;
    		address -= 0x6000;
    	} else {
    		if (address >= 0x4000) return 0;
    		if (address >= 0x2000) {
    			address -= 0x2000;
    		} else {
    			address += 0x2000;
    		}
    	}
    	
		return ramAddress + page*0x4000 + address;
    } 
    
    public static Integer get(Long address, int nbBytes)
    {
    	if (address==null) return 0;
    	
        Integer result = 0;
        Memory x_velMem = OS.readMemory(address, nbBytes);
	        
        for (int i = 0; i < nbBytes; i++) {
        	result += (x_velMem.getByte(i) & 0xff) << (8*(nbBytes-1-i)) ;
        }
        return result;
    } 
    
    public static void searchRamAddress() {
    	// Scan the emulator's memory for the TO8 boot-logo signature; the backend
    	// knows how to walk its own address space (Win32 module vs Mach regions).
    	ramAddress = OS.findSignature(key, keypos);
    	if (ramAddress != 0) {
    		portAddress  = ramAddress+0x80000; // port[0x40]   ports d'entrees/sorties
    		ddrAddress   = portAddress+0x40;   // ddr[0x40]    registres de direction des PIA 6821
    		plineAddress = ddrAddress+0x40;    // pline[0x40]  peripheral input-control lines des PIA 6821
    		carAddress   = plineAddress+0x40;  // car[0x20000] espace cartouche 8x16K (pour OS-9)
    		x7daAddress  = ramAddress+0x805C0; // x7da[0x20]   stockage de la palette de couleurs
    	}
    }

}
