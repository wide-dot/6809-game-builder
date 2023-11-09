package com.widedot.toolbox.debug.ui;

import com.widedot.toolbox.debug.Emulator;
import com.widedot.toolbox.debug.Symbols;

import imgui.ImColor;
import imgui.ImVec2;
import imgui.internal.ImGui;
import imgui.type.ImBoolean;
import imgui.type.ImInt;
import imgui.type.ImString;
import imgui.flag.ImGuiCol;
import imgui.flag.ImGuiInputTextFlags;
import imgui.flag.ImGuiStyleVar;

public class Tlsf {

	private static final int GREY = ImColor.intToColor(0x80, 0x80, 0x80, 0xFF);
	private static final int ORANGE = ImColor.intToColor(0xB5, 0x98, 0x4D, 0xFF); 
	
	private static ImInt page = new ImInt(15);
	private static Integer address = 0;
	private static Integer size = 0;
	private static final int MAP_WIDTH = 128;
	private static final int MAP_HEIGHT = 256;
	private static int[] pixels = new int[MAP_WIDTH*MAP_HEIGHT];
	private static int[] pixelsRender = new int[MAP_WIDTH*MAP_HEIGHT];
	private static TextureLoader image = new TextureLoader();
	private static boolean[] sl = new boolean[12*16];
	
	public static void show(ImBoolean showImGui) {

		if (ImGui.begin("Two-Level Segregated Fit memory allocator", showImGui)) {
			String flBitmapArray[] = new String[16];
			String curStr;
			Long curAdr;
			Integer curVal;
			int col = 0;
			int sli = 0;

			curStr = Symbols.symbols.get("tlsf.fl.bitmap");
			curAdr = Emulator.getAbsoluteAddress(1, curStr);
			if (curAdr == null) {
				ImGui.end();
				return;
			}
			curVal = Emulator.get(curAdr, 2);
			String flBitmap = String.format("%16s", Integer.toBinaryString(curVal)).replace(' ', '0');
			for (int i = 0; i < 16; i++) {
				flBitmapArray[i] = flBitmap.substring(15 - i, 16 - i);
			}

			curStr = Symbols.symbols.get("tlsf.sl.bitmaps");
			Long slAdr = Emulator.getAbsoluteAddress(1, curStr);
			if (slAdr == null) {
				ImGui.end();
				return;
			}
			slAdr += 6; // padding

			curStr = Symbols.symbols.get("tlsf.headMatrix");
			Long matrixAdr = Emulator.getAbsoluteAddress(1, curStr);
			curAdr = matrixAdr;
			if (curAdr == null) {
				ImGui.end();
				return;
			}
			curAdr += 2; // padding
			matrixAdr += 2;

			int fl = 0;

			// RENDERING INDEX

			ImGui.text("TLSF INDEX");
			ImGui.text("");
			ImGui.text("  ");
			ImGui.sameLine();
			ImGui.pushStyleColor(ImGuiCol.Text, ORANGE);
			ImGui.text("FL");
			ImGui.popStyleColor();
			ImGui.sameLine();
			ImGui.pushStyleColor(ImGuiCol.Text, ORANGE);
			ImGui.text("              SL");
			for (int i = 0; i <= 15; i++) {
				ImGui.sameLine();
				ImGui.text(String.format("%4s", i));
			}
			ImGui.popStyleColor();

			// padding
			col = 0;
			ImGui.pushStyleColor(ImGuiCol.Text, GREY);
			for (int i = 0; i < 48; i++) {
				if (col == 0) {
					ImGui.pushStyleColor(ImGuiCol.Text, ORANGE);
					ImGui.text(String.format("%2s", fl));
					ImGui.popStyleColor();
					ImGui.sameLine();
					ImGui.text(" " + flBitmapArray[fl++]);
					ImGui.sameLine();
					ImGui.text("----------------");
					ImGui.sameLine();
				}
				ImGui.text("----");
				if (col < 15) {
					ImGui.sameLine();
					col++;
				} else {
					col = 0;
				}
				curAdr += 2;
				matrixAdr += 2;
			}
			ImGui.popStyleColor();

			ImGui.pushStyleColor(ImGuiCol.Text, ORANGE);
			ImGui.text(String.format("%2s", fl));
			ImGui.popStyleColor();
			ImGui.sameLine();
			ImGui.text(" " + flBitmapArray[fl++]);
			ImGui.sameLine();
			curVal = Emulator.get(slAdr, 2);
			for (int j=15; j>=1; j--) {
				sl[sli++] = (String.format("%16s", Integer.toBinaryString(curVal)).replace(' ', '0')).substring(j, j+1).equals("1");
			}

			ImGui.pushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0);
			ImGui.text((String.format("%16s", Integer.toBinaryString(curVal)).replace(' ', '0')).substring(0, 15));
			ImGui.sameLine();
			ImGui.popStyleVar();

			ImGui.pushStyleColor(ImGuiCol.Text, GREY);
			ImGui.text((String.format("%16s", Integer.toBinaryString(curVal)).replace(' ', '0')).substring(15, 16));
			ImGui.popStyleColor();
			ImGui.sameLine();

			slAdr += 2;
			ImGui.pushStyleColor(ImGuiCol.Text, GREY);
			ImGui.text("----");
			ImGui.popStyleColor();
			ImGui.sameLine();

			col = 1;
			for (int i = 0; i < 191; i++) {

				if (col == 0) {
					ImGui.pushStyleColor(ImGuiCol.Text, ORANGE);
					ImGui.text(String.format("%2s", fl));
					ImGui.popStyleColor();
					ImGui.sameLine();
					ImGui.text(" " + flBitmapArray[fl++]);
					ImGui.sameLine();
					curVal = Emulator.get(slAdr, 2);
					for (int j=15; j>=0; j--) {
						sl[sli++] = (String.format("%16s", Integer.toBinaryString(curVal)).replace(' ', '0')).substring(j, j+1).equals("1");
					}
					ImGui.text(String.format("%16s", Integer.toBinaryString(curVal)).replace(' ', '0'));
					ImGui.sameLine();
					slAdr += 2;
				}

				curVal = Emulator.get(curAdr, 2);
				ImGui.text(String.format("%04X", curVal));
				if (col < 15) {
					ImGui.sameLine();
					col++;
				} else {
					col = 0;
				}
				curAdr += 2;
			}

			ImGui.pushStyleColor(ImGuiCol.Text, ORANGE);
			ImGui.text(String.format("%2s", fl));
			ImGui.popStyleColor();
			ImGui.sameLine();
			ImGui.text(" " + flBitmapArray[fl++]);
			ImGui.sameLine();
			curVal = Emulator.get(slAdr, 2);
			sl[sli++] = (String.format("%16s", Integer.toBinaryString(curVal)).replace(' ', '0')).substring(15, 16).equals("1");

			ImGui.pushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0);
			ImGui.pushStyleColor(ImGuiCol.Text, GREY);
			ImGui.text((String.format("%16s", Integer.toBinaryString(curVal)).replace(' ', '0')).substring(0, 15));
			ImGui.popStyleColor();
			ImGui.sameLine();
			ImGui.popStyleVar();

			ImGui.text((String.format("%16s", Integer.toBinaryString(curVal)).replace(' ', '0')).substring(15, 16));
			ImGui.sameLine();

			curVal = Emulator.get(curAdr, 2);
			ImGui.text(String.format("%04X", curVal));

			for (int i = 0; i < 15; i++) {
				ImGui.sameLine();
				ImGui.pushStyleColor(ImGuiCol.Text, GREY);
				ImGui.text("----");
				ImGui.popStyleColor();
			}
			
			// Memory pool page
			ImGui.text("");
			ImGui.separator();
			ImGui.text("MEMORY POOL");
			ImGui.text("");
			ImGui.pushItemWidth(70);
			ImGui.inputInt("page", page);
			if (page.get()<0) {
				page.set(0);
			}
			if (page.get()>31) {
				page.set(31);
			}
			
			// Memory pool location
			curStr = Symbols.symbols.get("tlsf.memoryPool");
			curAdr = Emulator.getAbsoluteAddress(1, curStr);
			if (curAdr == null) {
				ImGui.end();
				return;
			}
			address = Emulator.get(curAdr, 2);
			ImGui.inputText("address", new ImString(String.format("%04X", address)), ImGuiInputTextFlags.ReadOnly);
			
			// Pool size
			curStr = Symbols.symbols.get("tlsf.memoryPool.size");
			curAdr = Emulator.getAbsoluteAddress(1, curStr);
			if (curAdr == null) {
				ImGui.end();
				return;
			}
			size = Emulator.get(curAdr, 2);
			ImGui.inputText("size", new ImString(String.format("%04X", size)), ImGuiInputTextFlags.ReadOnly);

			// Error code
			curStr = Symbols.symbols.get("tlsf.err");
			curAdr = Emulator.getAbsoluteAddress(1, curStr);
			if (curAdr == null) {
				ImGui.end();
				return;
			}
			curVal = Emulator.get(curAdr, 1);
			ImGui.inputText("error code", new ImString(String.format("%01X", curVal)), ImGuiInputTextFlags.ReadOnly);
			ImGui.popItemWidth();
			
			ImVec2 vMin = ImGui.getWindowContentRegionMin();
			vMin.x += ImGui.getWindowPos().x+150;
			vMin.y += ImGui.getWindowPos().y+350;
			int x1 = (int) vMin.x;
			int y1 = (int) vMin.y;
			
			// init pixel map
			if (!(size>pixels.length || size<=0)) {
			
				for (int i=0; i<size; i++) pixels[i] = 0xFF800000;
				for (int i=size; i<MAP_WIDTH*MAP_HEIGHT; i++) pixels[i] = 0x00000000;
				
				// parse free lists and update pixel map
				for (int i=0; i<12*16; i++) {
					if (sl[i]) {
						if (drawFreeBlock(matrixAdr + i*2) == false) {
							ImGui.getWindowDrawList().addImage(image.loadTexture(pixelsRender, MAP_WIDTH, MAP_HEIGHT), x1, y1, x1+4*MAP_WIDTH, y1+4*MAP_HEIGHT);
							ImGui.end();
							return;
						}
					}
				}
							
				for (int i=0; i<pixels.length; i++) pixelsRender[i]=pixels[i];
				ImGui.getWindowDrawList().addImage(image.loadTexture(pixelsRender, MAP_WIDTH, MAP_HEIGHT), x1, y1, x1+4*MAP_WIDTH, y1+4*MAP_HEIGHT);
			}
			
			ImGui.end();
		}
	}
	
	private static boolean drawFreeBlock(long curAdr) {
		int start = Emulator.get(curAdr, 2) - address;
		int end = start + (Emulator.get(Emulator.getAbsoluteAddress(page.get(), Emulator.get(curAdr, 2)), 2) & 0x7FFF) + 1 + 4; // size is stored as (val - 1), header size 4
		int j=start;
		
		if (start<0 || end>pixels.length || start+8>pixels.length) return false;
		
		// header
		while (j<start+4) pixels[j++] = 0xFF80FFFF;
		while (j<start+8) pixels[j++] = 0xFF40BBBB;
		// free space
		while (j<end) pixels[j++] = 0xFF808080;
		
		long next = Emulator.getAbsoluteAddress(page.get(), Emulator.get(curAdr, 2)+6);
		if ((Emulator.get(next, 2) - address) != 0xFFFF) return drawFreeBlock(next);
		return true;
	}
}
