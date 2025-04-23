package com.widedot.toolbox.debug.ui;

import com.widedot.toolbox.debug.Emulator;
import com.widedot.toolbox.debug.Symbols;
import com.widedot.toolbox.debug.types.VideoBufferImage;

import imgui.ImVec2;
import imgui.internal.ImGui;
import imgui.type.ImBoolean;

public class CollisionBox {

	private static final int COLOR_WHITE = 0xFFFFFFFF;
	private static final int COLOR_BLACK = 0xFF000000;
	private static final int COLOR_GREY = 0x88AAAAAA;
	private static final int COLOR_RED = 0x280000FF;
	private static final int COLOR_ORANGE = 0x2842ADF5;
	private static final int COLOR_PURPLE = 0x28FF00FF;
	private static final int COLOR_GREEN = 0x2800FF00;
	private static final int COLOR_BLUE = 0x28FF0000;	
	private static final int COLOR_LBLUE = 0x28FFEF0F;
	
	private static int xscale = 4;
	private static int yscale = 2;
	
	private static int XRES = 160;
	private static int YRES = 200;
	
	private static int VRES = 256;	
	
	private static int xoffset = (VRES-XRES)/2;
	private static int yoffset = (VRES-YRES)/2;

	private static ImVec2 vMin;
	
	public static ImBoolean workingChk = new ImBoolean(true);
	public static ImBoolean addressChk = new ImBoolean(true);
	public static ImBoolean potentialChk = new ImBoolean(true);
	public static VideoBufferImage image = new VideoBufferImage(XRES, YRES);
	
	public static void show(ImBoolean showImGui) {
		
        if (ImGui.begin("Collision", showImGui)) {
			vMin = ImGui.getWindowContentRegionMin();
			vMin.x += ImGui.getWindowPos().x;
			vMin.y += ImGui.getWindowPos().y+25;
			
	   	 	ImGui.checkbox("visible buffer##workingChk", workingChk);
	   	 	ImGui.sameLine();
	   	 	ImGui.checkbox("address##addressChk", addressChk);
	   	 	ImGui.sameLine();
	   	 	ImGui.checkbox("potential##potentialChk", potentialChk);
	   	 	
	   	 	ImGui.text("Page: "+image.getPage(workingChk));
			ImGui.getWindowDrawList().addRectFilled(vMin.x, vMin.y, vMin.x+xscale*VRES, vMin.y+yscale*VRES, COLOR_GREY);
			int x1 = (int) vMin.x+xscale*xoffset;
			int y1 = (int) vMin.y+yscale*yoffset;
			int x2 = x1+xscale*XRES;
			int y2 = y1+yscale*YRES;
			
			ImGui.getWindowDrawList().addImage(image.get(workingChk), x1, y1, x2, y2);
			ImGui.getWindowDrawList().addRect(x1-1, y1-1, x2+1, y2+1, COLOR_PURPLE);
			
			displayList("AABB_list_friend", COLOR_GREEN);
			displayList("AABB_list_ennemy", COLOR_BLUE);
			displayList("AABB_list_ennemy_unkillable", COLOR_BLUE);
			displayList("AABB_list_player", COLOR_LBLUE);
			displayList("AABB_list_bonus", COLOR_PURPLE);
			displayList("AABB_list_forcepod", COLOR_ORANGE);
			displayList("AABB_list_foefire", COLOR_RED);
			displayList("AABB_list_supernova", COLOR_RED);
    	    ImGui.end();
        }
	}
	
	private static void displayList(String list, int color) {
    	String listFirst = Symbols.symbols.get(list);
    	if (listFirst == null) return;
    	
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

            ImGui.getWindowDrawList().addRect(xscale*xoffset+vMin.x+xscale*(cx-rx)-1, yscale*yoffset+vMin.y+yscale*(cy-ry)-1,
                    xscale*xoffset+vMin.x+xscale*(cx+rx+1)+1, yscale*yoffset+vMin.y+yscale*(cy+ry+1)+1, COLOR_BLACK);
            
            ImGui.getWindowDrawList().addRect(xscale*xoffset+vMin.x+xscale*(cx-rx), yscale*yoffset+vMin.y+yscale*(cy-ry),
            		                          xscale*xoffset+vMin.x+xscale*(cx+rx+1), yscale*yoffset+vMin.y+yscale*(cy+ry+1), COLOR_WHITE);
            
            ImGui.getWindowDrawList().addRect(xscale*xoffset+vMin.x+xscale*(cx-rx)+1, yscale*yoffset+vMin.y+yscale*(cy-ry)+1,
                    xscale*xoffset+vMin.x+xscale*(cx+rx+1)-1, yscale*yoffset+vMin.y+yscale*(cy+ry+1)-1, COLOR_WHITE);
			
            ImGui.getWindowDrawList().addRectFilled(xscale*xoffset+vMin.x+xscale*(cx-rx), yscale*yoffset+vMin.y+yscale*(cy-ry),
                    xscale*xoffset+vMin.x+xscale*(cx+rx+1), yscale*yoffset+vMin.y+yscale*(cy+ry+1), color);
            
            if (addressChk.get()) {
            	ImGui.getWindowDrawList().addText(ImGui.getFont(), 16, xscale*xoffset+vMin.x+xscale*(cx-rx), yscale*yoffset+vMin.y+yscale*(cy-ry-20),
            										COLOR_WHITE, Integer.toHexString(next));
            }
            
            if (potentialChk.get()) {
            	ImGui.getWindowDrawList().addText(ImGui.getFont(), 16, xscale*xoffset+vMin.x+xscale*(cx-rx), yscale*yoffset+vMin.y+yscale*(cy-ry-10),
            										COLOR_WHITE, ""+p);
            }
            
			next = Emulator.get(hitbox+7, 2);
            
   	 	} while (next != 0);
	}
}
