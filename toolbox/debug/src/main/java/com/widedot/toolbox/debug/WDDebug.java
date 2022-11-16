package com.widedot.toolbox.debug;

import imgui.ImGui;
import imgui.app.Application;
import imgui.app.Configuration;
import imgui.flag.ImGuiInputTextFlags;
import imgui.flag.ImGuiWindowFlags;
import imgui.type.ImString;

public class WDDebug extends Application {
	
	private Symbols s;
    private final ImString str = new ImString(5);
	
    public WDDebug(Symbols symbols) {
    	s = symbols;
    	launch(this);
    } 
	
    @Override
    protected void configure(Configuration config) {
        config.setTitle("wide-dot debug tools");
    }

    @Override
    public void process() {
    	 	
    	if (Emulator.pid == 0) {
    		ImGui.text("Waiting for process <"+Emulator.processName+">");
    		Emulator.pid = OS.getProcessId(Emulator.processName);
    		Emulator.process = OS.openProcess(OS.PROCESS_VM_READ|OS.PROCESS_VM_OPERATION, Emulator.pid);
    		return;
    	}
    	
    	if (Emulator.process != null) {
    		ImGui.text("image_set:"+Emulator.getShort(s, "MainCharacter","image_set"));
    		ImGui.text("x_pos:"+Emulator.getShort(s, "MainCharacter","x_pos"));
    		ImGui.text("y_pos:"+Emulator.getShort(s, "MainCharacter","y_pos"));
    		ImGui.text("x_vel:"+Emulator.getShort(s, "MainCharacter","x_vel"));
    		ImGui.text("y_vel:"+Emulator.getShort(s, "MainCharacter","y_vel"));
    	}

        if (ImGui.begin("Search", ImGuiWindowFlags.AlwaysAutoResize)) {
            ImGui.inputText("symbol", str, ImGuiInputTextFlags.CallbackResize);
            ImGui.text("value: " + Emulator.getShort(s, str.get()));
        }
        ImGui.end();
    }
}