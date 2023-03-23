package com.widedot.toolbox.debug.ui;

import com.sun.jna.Memory;
import com.widedot.toolbox.debug.Emulator;
import com.widedot.toolbox.debug.OS;
import com.widedot.toolbox.debug.Symbols;

import imgui.ImVec2;
import imgui.internal.ImGui;
import imgui.type.ImBoolean;

public class CollisionBox {

	private static final int COLOR_WHITE = 0xFFFFFFFF;
	private static final int COLOR_GREY = 0xFFAAAAAA;
	private static final int COLOR_RED = 0xFF0000FF;
	private static final int COLOR_PURPLE = 0xFFFF0FE7;
	private static final int COLOR_GREEN = 0xFF00FF00;
	private static final int COLOR_BLUE = 0xFFFF0000;	
	private static final int COLOR_LBLUE = 0xFFFFEF0F;
	private static int to8RGB[] = {0,  97, 122, 143, 158, 171, 184, 194, 204, 212, 219, 227, 235, 242, 250, 255};
	
	private static int xscale = 4;
	private static int yscale = 2;
	
	private static int XRES = 160;
	private static int YRES = 200;
	
	private static int VRES = 256;	
	
	private static int vp_x = 144;
	private static int vp_y = 180;
	
	private static int xoffset = (VRES-vp_x)/2;
	private static int yoffset = (VRES-vp_y)/2;

	private static ImVec2 vMin;
	
	private static int[] pixels = new int[XRES*YRES];
	private static int[] color = new int[16];
	
	public static void show(ImBoolean showImGui) {
		
        if (ImGui.begin("Collision", showImGui)) {
			vMin = ImGui.getWindowContentRegionMin();
			vMin.x += ImGui.getWindowPos().x;
			vMin.y += ImGui.getWindowPos().y;
			
			Memory ramB = OS.readMemory(Emulator.process, Emulator.ramAddress+3*0x4000, 8000);
			Memory ramA = OS.readMemory(Emulator.process, Emulator.ramAddress+3*0x4000+0x2000, 8000);
			
			Memory color4bit = OS.readMemory(Emulator.process, Emulator.x7daAddress, 0x20);
			for (int c=0; c < 0x20; c = c + 2) {
				color[c/2] = 0xFF000000 | (to8RGB[(color4bit.getByte(c) & 0x0f)] << 16) | (to8RGB[(color4bit.getByte(c) & 0xf0) >> 4] << 8) | to8RGB[color4bit.getByte(c+1) & 0x0f];
			}
			
			int j = 0;
	        for (int i = 0; i < pixels.length; i=i+4) {
	        	j = i/4;
	        	pixels[i]   = color[(ramA.getByte(j) & 0xf0) >> 4];
	        	pixels[i+1] = color[(ramA.getByte(j) & 0x0f)];
	        	pixels[i+2] = color[(ramB.getByte(j) & 0xf0) >> 4];
	        	pixels[i+3] = color[(ramB.getByte(j) & 0x0f)];
	        }
			
			int image = TextureLoader.loadTexture(pixels, XRES, YRES);

			ImGui.getWindowDrawList().addRectFilled(vMin.x, vMin.y, vMin.x+xscale*VRES, vMin.y+yscale*VRES, COLOR_GREY);
			int x1 = (int) vMin.x+xscale*((VRES-XRES)/2);
			int y1 = (int) vMin.y+yscale*((VRES-YRES)/2);
			int x2 = x1+xscale*XRES;
			int y2 = y1+yscale*YRES;
			ImGui.getWindowDrawList().addImage(image, x1, y1, x2, y2);
			//ImGui.getWindowDrawList().addRect(x1, y1, x2, y2, COLOR_WHITE);
			
			displayList("AABB_list_friend", COLOR_GREEN);
			displayList("AABB_list_ennemy", COLOR_BLUE);
			displayList("AABB_list_player", COLOR_LBLUE);
			displayList("AABB_list_bonus", COLOR_PURPLE);
	   	 	
    	    ImGui.end();
        }
	}
	
	private static void displayList(String list, int color) {
    	String listFirst = Symbols.symbols.get(list);
   	 	Long curAdr = Emulator.getAbsoluteAddress(1, listFirst);
   	 	if (curAdr==null) {return;}
   	 	Integer next = Emulator.get(curAdr, 2);
   	 	if (next==0) {return;}
   	 	int p=0, rx=0, ry=0, cx=0, cy=0, prev=0;
   	 	do {
	   	 	Long hitbox = Emulator.getAbsoluteAddress(1, next);
	   	 	
	   	 	if (hitbox == null)
	   	 		break;
	   	 	
			p = Emulator.get(hitbox, 1);
			rx = Emulator.get(hitbox+1, 1);
			ry = Emulator.get(hitbox+2, 1);
			cx = Emulator.get(hitbox+3, 1);
			cy = Emulator.get(hitbox+4, 1);
			prev = Emulator.get(hitbox+5, 2);
			
            ImGui.getWindowDrawList().addRect(xscale*xoffset+vMin.x+xscale*(cx-rx), yscale*yoffset+vMin.y+yscale*(cy-ry), xscale*xoffset+vMin.x+xscale*(cx+rx), yscale*yoffset+vMin.y+yscale*(cy+ry), color);
            ImGui.getWindowDrawList().addText(xscale*xoffset+vMin.x+xscale*(cx-rx), yscale*yoffset+vMin.y+yscale*(cy-ry-10), COLOR_WHITE, Integer.toHexString(next)+" p:"+p);
            
			next = Emulator.get(hitbox+7, 2);
            
   	 	} while (next != 0);
	}
}
