package com.widedot.toolbox.debug;

import com.sun.jna.Memory;
import com.sun.jna.Pointer;

public class Emulator {
	public static final String processName= " DCMOTO 2022.04.24 - Emulateur de tous les ordinateurs 8 bits Thomson";
	public static int pid = 0;
	public static Pointer process = null;

	public static final long ramAddress   = 0x00007F47C0;       // ram[0x80000] ram (maxi 512K pour TO9+)
	public static final long portAddress  = ramAddress+0x80000; // port[0x40]   ports d'entrees/sorties
	public static final long ddrAddress   = portAddress+0x40;   // ddr[0x40]    registres de direction des PIA 6821
	public static final long plineAddress = ddrAddress+0x40;    // pline[0x40]  peripheral input-control lines des PIA 6821
	public static final long carAddress   = plineAddress+0x40;  // car[0x20000] espace cartouche 8x16K (pour OS-9)
	public static final long x7daAddress  = carAddress+0x20000; // x7da[0x20]   stockage de la palette de couleurs
	
    public static short getShort(Symbols s, String symbol) {
    	int page = 0;
    	Integer address = s.map.get(symbol);
    	if (address == null) {
    		return 0;
    	}
    	
    	if (address >= 0x6000 && address < 0xA000) {
    		page = 1;
    		address -= 0x6000;
    	}

		return getShort(page, address);
    }   
	
    public static short getShort(Symbols s, String symbol, String symbolOffset) {
    	int page = 0;
    	int address = s.map.get(symbol) + s.map.get(symbolOffset);
    	
    	if (address >= 0x6000 && address < 0xA000) {
    		page = 1;
    		address -= 0x6000;
    	}

		return getShort(page, address);
    }   
    
    public static short getShort(int page, int address) {
    	long processAddr = ramAddress + page*0x4000 + address;
        Memory x_velMem = OS.readMemory(Emulator.process,processAddr,64);
		return (short) (((x_velMem.getByte(0) & 0xff) << 8) + (x_velMem.getByte(1) & 0xff));
    } 
}
