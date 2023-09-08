package com.widedot.toolbox.debug;

import java.nio.ByteBuffer;

import com.sun.jna.Memory;
import com.sun.jna.Pointer;
import com.widedot.toolbox.debug.types.Data;
import com.widedot.toolbox.debug.types.Watch;

public class Emulator {
	public static final String processName= "dcmoto_";
	public static int pid = 0;
	public static Pointer process = null;

	// pixels représentant la première ligne du logo TO de l'écran de démarrage du TO8 en mémoire vidéo
	public static byte[] key = new byte[]{0x00, 0x7F, (byte) 0xFF, (byte) 0xFF, (byte) 0xFF, (byte) 0xFF, (byte) 0xFF, (byte) 0xFE, 0x00, 0x00, (byte) 0xFF, (byte) 0xFF, (byte) 0xFF, (byte) 0xFF, (byte) 0xFF, 0x00};
	public static int keypos = 0x2190;
		
	public static long baseAddress  = 0;
	public static int baseSize  = 0;
	public static long ramAddress = 0;
	public static long portAddress = 0;  // port[0x40]   ports d'entrees/sorties
	public static long ddrAddress = 0;   // ddr[0x40]    registres de direction des PIA 6821
	public static long plineAddress = 0; // pline[0x40]  peripheral input-control lines des PIA 6821
	public static long carAddress = 0;   // car[0x20000] espace cartouche 8x16K (pour OS-9)
	public static long x7daAddress = 0;  // x7da[0x20]   stockage de la palette de couleurs
	
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
    
    public static void searchRamAddress() {
    	ByteBuffer buffer = OS.readMemory(Emulator.process,Emulator.baseAddress,baseSize).getByteBuffer(0, baseSize);
        for(int i = 0; i < baseSize - key.length+1; ++i) {
            boolean found = true;
            for(int j = 0; j < key.length; ++j) {
               if (buffer.get(i+j) != key[j]) {
                   found = false;
                   break;
               }
            }
            if (found) {
            	Emulator.ramAddress = Emulator.baseAddress + i - keypos;
            	System.out.println("RAM: "+Emulator.ramAddress);
            	portAddress  = ramAddress+0x80000; // port[0x40]   ports d'entrees/sorties
            	ddrAddress   = portAddress+0x40;   // ddr[0x40]    registres de direction des PIA 6821
            	plineAddress = ddrAddress+0x40;    // pline[0x40]  peripheral input-control lines des PIA 6821
            	carAddress   = plineAddress+0x40;  // car[0x20000] espace cartouche 8x16K (pour OS-9)
            	x7daAddress  = ramAddress+0x805C0; // x7da[0x20]   stockage de la palette de couleurs
            }
         }
    }  
     
}
