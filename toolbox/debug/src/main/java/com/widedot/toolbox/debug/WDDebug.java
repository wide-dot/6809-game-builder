package com.widedot.toolbox.debug;

import com.widedot.toolbox.debug.ui.*;

import imgui.ImGui;
import imgui.ImVec2;
import imgui.app.Application;
import imgui.app.Configuration;
import imgui.type.ImBoolean;
import imgui.ImColor;

public class WDDebug extends Application {
	
	// Dialog display status
    private static final ImBoolean SHOW_IMGUI_FILE_DIALOG_WINDOW = new ImBoolean(false);
    private static final ImBoolean SHOW_IMGUI_MEMORY_EDITOR_WINDOW = new ImBoolean(false);
    private static final ImBoolean SHOW_IMGUI_MEMORY_WATCH_WINDOW = new ImBoolean(false);
    private static final ImBoolean SHOW_IMGUI_COLLISION_WINDOW = new ImBoolean(false);
    private static final ImBoolean SHOW_IMGUI_OJECT_SLOTS_WINDOW = new ImBoolean(false);
    private static final ImBoolean SHOW_IMGUI_SMPS_WINDOW = new ImBoolean(false);
	
    public WDDebug() {
    	launch(this);
    } 
	
    @Override
    protected void configure(Configuration config) {
        config.setTitle("wide-dot debug tools");
    }

    @Override
    public void process() {
    	 	   	
    	// Menu Bar
        if (ImGui.beginMainMenuBar())
        {
            if (ImGui.beginMenu("Open"))
            {
            	ImGui.menuItem("Memory Map", null, SHOW_IMGUI_FILE_DIALOG_WINDOW);
            	ImGui.endMenu();
            }
            if (ImGui.beginMenu("Memory"))
            {
                ImGui.menuItem("Edit", null, SHOW_IMGUI_MEMORY_EDITOR_WINDOW);
                ImGui.menuItem("Watch", null, SHOW_IMGUI_MEMORY_WATCH_WINDOW);
                ImGui.endMenu();
            }
            if (ImGui.beginMenu("Engine"))
            {
                ImGui.menuItem("Collision", null, SHOW_IMGUI_COLLISION_WINDOW);
                ImGui.menuItem("Object slots", null, SHOW_IMGUI_OJECT_SLOTS_WINDOW);
                ImGui.menuItem("Smps driver", null, SHOW_IMGUI_SMPS_WINDOW);
                ImGui.endMenu();
            }

            ImGui.endMainMenuBar();
            
        }
        
        // Listening to emulator process
   		Emulator.pid = OS.getProcessId(Emulator.processName);
    	if (Emulator.pid == 0) {
       		ImGui.text("Waiting for process <"+Emulator.processName+"*.exe>");
    		return;
    	}
    	Emulator.process = OS.openProcess(OS.PROCESS_VM_READ|OS.PROCESS_VM_OPERATION, Emulator.pid);
        
        // Display active dialog boxes
        if (SHOW_IMGUI_FILE_DIALOG_WINDOW.get()) MemoryMap.show(SHOW_IMGUI_FILE_DIALOG_WINDOW);
        if (SHOW_IMGUI_MEMORY_EDITOR_WINDOW.get()) MemoryEditor.show(SHOW_IMGUI_MEMORY_EDITOR_WINDOW);
        if (SHOW_IMGUI_MEMORY_WATCH_WINDOW.get()) MemoryWatch.show(SHOW_IMGUI_MEMORY_WATCH_WINDOW);
        if (SHOW_IMGUI_COLLISION_WINDOW.get()) CollisionBox.show(SHOW_IMGUI_COLLISION_WINDOW);
        if (SHOW_IMGUI_OJECT_SLOTS_WINDOW.get()) ObjectSlots.show(SHOW_IMGUI_OJECT_SLOTS_WINDOW);
        if (SHOW_IMGUI_SMPS_WINDOW.get()) SmpsDriver.show(SHOW_IMGUI_SMPS_WINDOW);
        
        ImGui.text(String.format("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / ImGui.getIO().getFramerate(), ImGui.getIO().getFramerate()));
    }
}