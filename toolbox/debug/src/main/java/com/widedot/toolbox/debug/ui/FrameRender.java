package com.widedot.toolbox.debug.ui;

import com.widedot.toolbox.debug.types.DcmotoTrace;
import imgui.internal.ImGui;
import imgui.type.ImBoolean;

public class FrameRender {
	
	public static boolean processed = false; 
	
	public static void show(ImBoolean showImGui) {
		
		if (ImGui.begin("Frame Render", showImGui)&&processed==false) {
			new DcmotoTrace();
			processed = true;
		}
		ImGui.end();
	}

}
