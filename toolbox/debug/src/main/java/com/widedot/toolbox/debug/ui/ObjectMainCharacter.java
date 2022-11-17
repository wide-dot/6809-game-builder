package com.widedot.toolbox.debug.ui;

import com.widedot.toolbox.debug.Emulator;
import com.widedot.toolbox.debug.Symbols;

import imgui.internal.ImGui;
import imgui.type.ImBoolean;

public class ObjectMainCharacter {

	public static void show(ImBoolean showImGui, Symbols s) {

        if (ImGui.begin("Object - Main Character", showImGui)) {
    		ImGui.text("image_set:"+Emulator.getShort(s, "MainCharacter","image_set"));
    		ImGui.text("x_pos:"+Emulator.getShort(s, "MainCharacter","x_pos"));
    		ImGui.text("y_pos:"+Emulator.getShort(s, "MainCharacter","y_pos"));
    		ImGui.text("x_vel:"+Emulator.getShort(s, "MainCharacter","x_vel"));
    		ImGui.text("y_vel:"+Emulator.getShort(s, "MainCharacter","y_vel"));
    	    ImGui.end();
        }
	}
}
