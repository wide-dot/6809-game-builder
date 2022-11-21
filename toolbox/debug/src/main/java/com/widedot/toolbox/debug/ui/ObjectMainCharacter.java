package com.widedot.toolbox.debug.ui;

import com.widedot.toolbox.debug.Emulator;

import imgui.internal.ImGui;
import imgui.type.ImBoolean;

public class ObjectMainCharacter {

	public static void show(ImBoolean showImGui) {

        if (ImGui.begin("Object - Main Character", showImGui)) {
//    		ImGui.text("image_set:"+Emulator.get("MainCharacter","image_set"));
//    		ImGui.text("x_pos:"+Emulator.get("MainCharacter","x_pos"));
//    		ImGui.text("y_pos:"+Emulator.get("MainCharacter","y_pos"));
//    		ImGui.text("x_vel:"+Emulator.get("MainCharacter","x_vel"));
//    		ImGui.text("y_vel:"+Emulator.get("MainCharacter","y_vel"));
    	    ImGui.end();
        }
	}
}
