package com.widedot.toolbox.debug.ui;

import com.widedot.toolbox.debug.Emulator;
import com.widedot.toolbox.debug.Symbols;

import imgui.ImColor;
import imgui.internal.ImGui;
import imgui.type.ImBoolean;
import imgui.flag.ImGuiCol;
import imgui.flag.ImGuiStyleVar;

public class Tlsf {

	private static final int GREY = ImColor.intToColor(0x80, 0x80, 0x80, 0xFF);
	private static final int ORANGE = ImColor.intToColor(0xB5, 0x98, 0x4D, 0xFF); 

	public static void show(ImBoolean showImGui) {

		if (ImGui.begin("Two-Level Segregated Fit memory allocator", showImGui)) {
			String flBitmapArray[] = new String[16];
			String curStr;
			Long curAdr;
			Integer curVal;
			int col = 0;

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
			curAdr = Emulator.getAbsoluteAddress(1, curStr);
			if (curAdr == null) {
				ImGui.end();
				return;
			}
			curAdr += 2; // padding

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
			for (int i = 1; i <= 16; i++) {
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
			}
			ImGui.popStyleColor();

			ImGui.pushStyleColor(ImGuiCol.Text, ORANGE);
			ImGui.text(String.format("%2s", fl));
			ImGui.popStyleColor();
			ImGui.sameLine();
			ImGui.text(" " + flBitmapArray[fl++]);
			ImGui.sameLine();
			curVal = Emulator.get(slAdr, 2);

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
			ImGui.sameLine();

			for (int i = 0; i < 15; i++) {
				ImGui.pushStyleColor(ImGuiCol.Text, GREY);
				ImGui.text("----");
				ImGui.popStyleColor();
				ImGui.sameLine();
			}

			ImGui.end();
		}
	}
}
