package com.widedot.toolbox.debug;

import com.sun.jna.Memory;
import com.sun.jna.Pointer;
import com.widedot.toolbox.debug.types.Data;
import com.widedot.toolbox.debug.types.Watch;

public class Emulator {
	public static final String processName= "dcmoto_";
	public static int pid = 0;
	public static Pointer process = null;

	// chaine sur l'ecran de boot TO8:
	// 00 7F FF FF FF FF FF FE 00 00 FF FF FF FF FF 00
	// lue en 41F990, donne 81D800 (-190-400000-2000) (dans 010 editor : 0x41C800)
	
	 public static final long ramAddress   = 0x000081D800;       // ram[0x80000] ram (maxi 512K pour TO9+) 2023.02.25
	// public static final long ramAddress   = 0x00007F67C0;       // ram[0x80000] ram (maxi 512K pour TO9+) dcmoto 2023.01.30
	// public static final long ramAddress   = 0x000081E800;       // ram[0x80000] ram (maxi 512K pour TO9+) dcmoto 2023.02.13

	public static final long portAddress  = ramAddress+0x80000; // port[0x40]   ports d'entrees/sorties
	public static final long ddrAddress   = portAddress+0x40;   // ddr[0x40]    registres de direction des PIA 6821
	public static final long plineAddress = ddrAddress+0x40;    // pline[0x40]  peripheral input-control lines des PIA 6821
	public static final long carAddress   = plineAddress+0x40;  // car[0x20000] espace cartouche 8x16K (pour OS-9)
	public static final long x7daAddress  = ramAddress+0x805C0; // x7da[0x20]   stockage de la palette de couleurs
	// palette reel 49CDC0
	
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
        Memory x_velMem = OS.readMemory(Emulator.process, processAddr, Data.byteLen.get(w.value.type));
        
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
    
    public static Long getAbsoluteAddress(int page, Integer address)
    {
 	   	if (address == null) return null;
    	
    	if (address >= 0x6000 && address < 0xA000) {
    		page = 1;
    		address -= 0x6000;
    	}
    	
    	if (address >= 0x4000) return null;
    	
		return ramAddress + page*0x4000 + address;
    } 
    
    public static Integer get(Long address, int nbBytes)
    {
        Integer result = 0;
        Memory x_velMem = OS.readMemory(Emulator.process, address, nbBytes);
	        
        for (int i = 0; i < nbBytes; i++) {
        	result += (x_velMem.getByte(i) & 0xff) << (8*(nbBytes-1-i)) ;
        }
        return result;
    } 
     
}
