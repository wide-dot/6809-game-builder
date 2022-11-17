package com.widedot.toolbox.debug.ui;


import com.widedot.toolbox.debug.Emulator;
import com.widedot.toolbox.debug.Symbols;

import imgui.flag.ImGuiInputTextFlags;
import imgui.internal.ImGui;
import imgui.type.ImBoolean;
import imgui.type.ImString;

public class MemoryWatch {

    private final static ImString str = new ImString(5);
    
	public static void show(ImBoolean showImGui, Symbols s) {

   	    if (ImGui.begin("Search", showImGui)) {
   	        ImGui.inputText("symbol", str, ImGuiInputTextFlags.CallbackResize);
   	        ImGui.text("value: " + Emulator.getShort(s, str.get()));
   		    ImGui.end();
   	    }
	}
}
