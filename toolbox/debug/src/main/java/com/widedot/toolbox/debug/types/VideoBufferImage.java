package com.widedot.toolbox.debug.types;

import com.sun.jna.Memory;
import com.widedot.toolbox.debug.Emulator;
import com.widedot.toolbox.debug.OS;
import com.widedot.toolbox.debug.Symbols;
import com.widedot.toolbox.debug.ui.TextureLoader;

import imgui.type.ImBoolean;

public class VideoBufferImage {

	private static int ThomsonRGB[] = {0,  97, 122, 143, 158, 171, 184, 194, 204, 212, 219, 227, 235, 242, 250, 255};
	private static int xres;
	private static int yres;
	private static int[] pixels;
	private static int[] color = new int[16];
	
	public VideoBufferImage(int xr, int yr) {
		xres = xr;
		yres = yr;
		pixels = new int[xres*yres];
	}

	public int getPage(ImBoolean workingChk) {
	 	String var = Symbols.symbols.get("glb_Cur_Wrk_Screen_Id");
	 	Long pos = Emulator.getAbsoluteAddress(1, var);
	 	Integer page = Emulator.get(pos, 1);
	 	Integer wrkPage = page+2;
	 	return (workingChk.get()?wrkPage^1:wrkPage);
	}
	
	public int get(ImBoolean workingChk) {
		int curPage = getPage(workingChk);
		Memory ramB = OS.readMemory(Emulator.process, Emulator.ramAddress+curPage*0x4000, 8000);
		Memory ramA = OS.readMemory(Emulator.process, Emulator.ramAddress+curPage*0x4000+0x2000, 8000);
		
		Memory color4bit = OS.readMemory(Emulator.process, Emulator.x7daAddress, 0x20);
		for (int c=0; c < 0x20; c = c + 2) {
			color[c/2] = 0xFF000000 | (ThomsonRGB[(color4bit.getByte(c) & 0x0f)] << 16) | (ThomsonRGB[(color4bit.getByte(c) & 0xf0) >> 4] << 8) | ThomsonRGB[color4bit.getByte(c+1) & 0x0f];
		}
		
		int j = 0;
	    for (int i = 0; i < pixels.length; i=i+4) {
	    	j = i/4;
	    	pixels[i]   = color[(ramA.getByte(j) & 0xf0) >> 4];
	    	pixels[i+1] = color[(ramA.getByte(j) & 0x0f)];
	    	pixels[i+2] = color[(ramB.getByte(j) & 0xf0) >> 4];
	    	pixels[i+3] = color[(ramB.getByte(j) & 0x0f)];
	    }
	    return TextureLoader.loadTexture(pixels, xres, yres);
	}
}
