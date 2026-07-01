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
	
	public static TextureLoader image;
	
	public VideoBufferImage(int xr, int yr) {
		xres = xr;
		yres = yr;
		pixels = new int[xres*yres];
		image = new TextureLoader();
	}

	public int getPage(ImBoolean workingChk) {
	 	String var = Symbols.symbols.get("gfxlock.backBuffer.id");
	 	Long pos = Emulator.getAbsoluteAddress(1, var);
	 	Integer page = Emulator.get(pos, 1);
	 	Integer wrkPage = page+2;
	 	return (workingChk.get()?wrkPage^1:wrkPage);
	}
	
	public int get(ImBoolean workingChk) {
		int curPage = getPage(workingChk);
		Memory ramB = OS.readMemory(Emulator.ramAddress+curPage*0x4000, 8000);
		Memory ramA = OS.readMemory(Emulator.ramAddress+curPage*0x4000+0x2000, 8000);

		// The palette location and byte layout depend on the DCMOTO build; both are
		// resolved at hook time by Emulator.searchPaletteAddress (see Emulator).
		if (Emulator.paletteFormat == Emulator.PAL_BGRX) {
			// 16 colours x 4 bytes: B, G, R, 00 (already-decoded 8-bit RGB).
			Memory pal = OS.readMemory(Emulator.paletteAddress, 16 * 4);
			for (int k = 0; k < 16; k++) {
				int b = pal.getByte(k*4)   & 0xff;
				int g = pal.getByte(k*4+1) & 0xff;
				int r = pal.getByte(k*4+2) & 0xff;
				color[k] = 0xFF000000 | (r << 16) | (g << 8) | b;
			}
		} else if (Emulator.paletteFormat == Emulator.PAL_NIBBLE) {
			// 16 colours x 2 bytes: even = (green<<4)|red, odd low nibble = blue.
			Memory color4bit = OS.readMemory(Emulator.paletteAddress, 0x20);
			for (int c=0; c < 0x20; c = c + 2) {
				color[c/2] = 0xFF000000 | (ThomsonRGB[(color4bit.getByte(c) & 0x0f)] << 16) | (ThomsonRGB[(color4bit.getByte(c) & 0xf0) >> 4] << 8) | ThomsonRGB[color4bit.getByte(c+1) & 0x0f];
			}
		} else {
			// PAL_NONE: palette not located yet -> grayscale ramp so shapes stay visible
			for (int k = 0; k < 16; k++) {
				int g = k * 17;
				color[k] = 0xFF000000 | (g << 16) | (g << 8) | g;
			}
		}
		
		int j = 0;
	    for (int i = 0; i < pixels.length; i=i+4) {
	    	j = i/4;
	    	pixels[i]   = color[(ramA.getByte(j) & 0xf0) >> 4];
	    	pixels[i+1] = color[(ramA.getByte(j) & 0x0f)];
	    	pixels[i+2] = color[(ramB.getByte(j) & 0xf0) >> 4];
	    	pixels[i+3] = color[(ramB.getByte(j) & 0x0f)];
	    }
	    return image.loadTexture(pixels, xres, yres);
	}
}
