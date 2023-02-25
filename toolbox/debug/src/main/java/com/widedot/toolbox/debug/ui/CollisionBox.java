package com.widedot.toolbox.debug.ui;

import com.widedot.toolbox.debug.Emulator;
import com.widedot.toolbox.debug.Symbols;

import imgui.ImVec2;
import imgui.internal.ImGui;
import imgui.type.ImBoolean;

public class CollisionBox {

	private static final int WHITE_COLOR = 0xFFFFFFFF;
	private static final int GREY_COLOR = 0xFFAAAAAA;
	
	private static final int PLAYER_COLOR = 0xFF00FF00;
	private static final int PLAYER_COLOR_HIT = 0xFF0000FF;
	private static final int PLAYER_LIST = 0;
	
	private static final int AI_COLOR = 0xFFFF0000;
	private static final int AI_COLOR_HIT = 0xFF0000FF;
	private static final int AI_LIST = 1;
	
	private static int xscale = 4;
	private static int yscale = 2;
	private static ImVec2 vMin;
	
	public static void show(ImBoolean showImGui) {
		
        if (ImGui.begin("Collision", showImGui)) {
			vMin = ImGui.getWindowContentRegionMin();
			vMin.x += ImGui.getWindowPos().x;
			vMin.y += ImGui.getWindowPos().y;
			
			ImGui.getWindowDrawList().addRectFilled(vMin.x, vMin.y, vMin.x+xscale*256, vMin.y+yscale*256, GREY_COLOR);
			ImGui.getWindowDrawList().addRect(vMin.x+xscale*((256-160)/2), vMin.y+yscale*((256-200)/2), vMin.x+xscale*((256-160)/2+160), vMin.y+yscale*((256-200)/2+200), WHITE_COLOR);
			
			displayList("AABB_player_first", PLAYER_LIST);
			displayList("AABB_ai_first", AI_LIST);
	   	 	
    	    ImGui.end();
        }
	}
	
	private static void displayList(String list, int listColor) {
    	String listFirst = Symbols.symbols.get(list);
   	 	Long curAdr = Emulator.getAbsoluteAddress(1, listFirst);
   	 	if (curAdr==null) {return;}
   	 	Integer next = Emulator.get(curAdr, 2);
   	 	if (next==0) {return;}
   	 	int p=0, rx=0, ry=0, cx=0, cy=0, prev=0;
   	 	do {
	   	 	Long hitbox = Emulator.getAbsoluteAddress(1, next);
	   	 	
			p = Emulator.get(hitbox, 1);
			rx = Emulator.get(hitbox+1, 1);
			ry = Emulator.get(hitbox+2, 1);
			cx = Emulator.get(hitbox+3, 1);
			cy = Emulator.get(hitbox+4, 1);
			prev = Emulator.get(hitbox+5, 2);
			
            ImGui.getWindowDrawList().addRect(vMin.x+xscale*(cx-rx), vMin.y+yscale*(cy-ry), vMin.x+xscale*(cx+rx), vMin.y+yscale*(cy+ry), (listColor==PLAYER_LIST?(p!=0?PLAYER_COLOR:PLAYER_COLOR_HIT):(p!=0?AI_COLOR:AI_COLOR_HIT)));
            ImGui.getWindowDrawList().addText(vMin.x+xscale*(cx-rx), vMin.y+yscale*(cy-ry-10), WHITE_COLOR, Integer.toHexString(next)+" p:"+p);
            
			next = Emulator.get(hitbox+7, 2);
            
   	 	} while (next != 0);
	}
}
