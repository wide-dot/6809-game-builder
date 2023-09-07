package com.widedot.toolbox.debug;

import com.sun.jna.Memory;
import com.sun.jna.Pointer;
import com.widedot.toolbox.debug.types.Data;
import com.widedot.toolbox.debug.types.Watch;

public class Emulator {
	public static final String processName= "dcmoto_";
	public static int pid = 0;
	public static Pointer process = null;

	public static byte[] key = new byte[]{0x00, 0x7F, (byte) 0xFF, (byte) 0xFF, (byte) 0xFF, (byte) 0xFF, (byte) 0xFF, (byte) 0xFE, 0x00, 0x00, (byte) 0xFF, (byte) 0xFF, (byte) 0xFF, (byte) 0xFF, (byte) 0xFF, 0x00};
	
	// chaine sur l'ecran de boot TO8:
	// 00 7F FF FF FF FF FF FE 00 00 FF FF FF FF FF 00 (position 0x4190 en RAM => page 0
	// lue en 41F990, donne 81D800 (-190-400000-2000) (dans 010 editor : 0x41C800)
	// x41F990 : x4190
	// x41F800 : x4000
	// x41E800 : x3000
	// x41D800 : x2000
	// x41C800 : x1000
	// x41B800 : x0000 + x402000 = x81D800
	// x400000 = base du process (a récupérer dynamiquement = adresse du module)
	// x2000 => le fait que ce soit la partie haute de la page 0 ?
	
	public static long baseAddress  = 0;
	public static long ramAddress = 0x402000; // search
	// public static final long ramAddress   = 0x000081D800;       // ram[0x80000] ram (maxi 512K pour TO9+) 2023.02.25
	// public static final long ramAddress   = 0x00007F67C0;       // ram[0x80000] ram (maxi 512K pour TO9+) dcmoto 2023.01.30
	// public static final long ramAddress   = 0x000081E800;       // ram[0x80000] ram (maxi 512K pour TO9+) dcmoto 2023.02.13

	public static final long portAddress  = baseAddress+ramAddress+0x80000; // port[0x40]   ports d'entrees/sorties
	public static final long ddrAddress   = portAddress+0x40;   // ddr[0x40]    registres de direction des PIA 6821
	public static final long plineAddress = ddrAddress+0x40;    // pline[0x40]  peripheral input-control lines des PIA 6821
	public static final long carAddress   = plineAddress+0x40;  // car[0x20000] espace cartouche 8x16K (pour OS-9)
	public static final long x7daAddress  = baseAddress+ramAddress+0x805C0; // x7da[0x20]   stockage de la palette de couleurs
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

    	long processAddr = baseAddress+ramAddress + page*0x4000 + address;
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
    	
		return baseAddress+ramAddress + page*0x4000 + address;
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
    
    public static int setRamAddress() {
	byte[] outerArray = OS.readMemory(Emulator.process, 0, 0x800000).getByteArray(0, 0x800000);
        for(int i = 0; i < outerArray.length - key.length+1; ++i) {
            boolean found = true;
            for(int j = 0; j < key.length; ++j) {
               if (outerArray[i+j] != key[j]) {
                   found = false;
                   break;
               }
            }
            if (found) return i;
         }
       return -1;  
    }  
     
}
