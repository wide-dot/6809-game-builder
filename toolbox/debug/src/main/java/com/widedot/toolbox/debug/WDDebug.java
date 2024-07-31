package com.widedot.toolbox.debug;

import com.sun.jna.Pointer;
import com.sun.jna.platform.win32.Tlhelp32;
import com.widedot.toolbox.debug.ui.*;

import imgui.ImGui;
import imgui.ImGuiIO;
import imgui.app.Application;
import imgui.app.Configuration;
import imgui.flag.ImGuiBackendFlags;
import imgui.type.ImBoolean;

public class WDDebug extends Application {
	
	public static int curPid = 0;
	public static Tlhelp32.MODULEENTRY32W module;
	
	// Dialog display status
    private static final ImBoolean SHOW_IMGUI_FILE_DIALOG_WINDOW = new ImBoolean(false);
    private static final ImBoolean SHOW_IMGUI_MEMORY_EDITOR_WINDOW = new ImBoolean(false);
    private static final ImBoolean SHOW_IMGUI_MEMORY_WATCH_WINDOW = new ImBoolean(false);
    private static final ImBoolean SHOW_IMGUI_TLSF_WINDOW = new ImBoolean(false);
    private static final ImBoolean SHOW_IMGUI_COLLISION_WINDOW = new ImBoolean(false);
    private static final ImBoolean SHOW_IMGUI_FRAME_RENDER_WINDOW = new ImBoolean(false);
    private static final ImBoolean SHOW_IMGUI_SPRITE_RENDER_WINDOW = new ImBoolean(false);
    private static final ImBoolean SHOW_IMGUI_OJECT_SLOTS_WINDOW = new ImBoolean(false);
    private static final ImBoolean SHOW_IMGUI_SMPS_WINDOW = new ImBoolean(false);
    private static final ImBoolean SHOW_IMGUI_MEA_WINDOW = new ImBoolean(false);
	
    public WDDebug() {
    	launch(this);
    } 
	
    @Override
    protected void configure(Configuration config) {
        config.setTitle("wide-dot debug tools");
    }

    @Override
    public void process() {
    	 	   	
    	// move this to init instead of process
        final ImGuiIO io = ImGui.getIO();
        io.addBackendFlags(ImGuiBackendFlags.RendererHasVtxOffset);
    	
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
                ImGui.menuItem("Tlsf", null, SHOW_IMGUI_TLSF_WINDOW);
                ImGui.endMenu();
            }
            if (ImGui.beginMenu("Engine"))
            {
                ImGui.menuItem("Collision", null, SHOW_IMGUI_COLLISION_WINDOW);
                ImGui.menuItem("Frame Render", null, SHOW_IMGUI_FRAME_RENDER_WINDOW);
                ImGui.menuItem("Sprite Render", null, SHOW_IMGUI_SPRITE_RENDER_WINDOW);
                ImGui.menuItem("Object slots", null, SHOW_IMGUI_OJECT_SLOTS_WINDOW);
                ImGui.menuItem("Smps driver", null, SHOW_IMGUI_SMPS_WINDOW);
                ImGui.endMenu();
            }
            if (ImGui.beginMenu("Tools"))
            {
                ImGui.menuItem("MEA8000", null, SHOW_IMGUI_MEA_WINDOW);
                ImGui.endMenu();
            }

            ImGui.endMainMenuBar();
            
        }

        // tools non related to process
        if (SHOW_IMGUI_FRAME_RENDER_WINDOW.get()) FrameRender.show(SHOW_IMGUI_FRAME_RENDER_WINDOW);
        if (SHOW_IMGUI_MEA_WINDOW.get()) MeaEmulator.show(SHOW_IMGUI_MEA_WINDOW);
        
        // Listening to emulator process
   		Emulator.pid = OS.getProcessId(Emulator.processName);
    	if (Emulator.pid == 0) {
       		ImGui.text("Waiting for process <"+Emulator.processName+"*.exe>.");
    		return;
    	}
    	// automatic hook
    	if (curPid != Emulator.pid || module == null || Emulator.ramAddress == 0) {
    		ImGui.text("Set DCMOTO mode to TO8 and make a hard reboot.");
    		curPid = Emulator.pid;
        	Emulator.process = OS.openProcess(OS.PROCESS_VM_READ|OS.PROCESS_VM_OPERATION, Emulator.pid);
    		module = OS.getModule(Emulator.pid, Emulator.processName);
    		if (module != null) {
	           	Emulator.baseAddress = Pointer.nativeValue(module.modBaseAddr);
	           	Emulator.baseSize = module.modBaseSize.intValue();
	    		Emulator.searchRamAddress();
	        	if (Emulator.ramAddress == 0) return;
    		}
    	}
    	
        // Display active dialog boxes
        if (SHOW_IMGUI_FILE_DIALOG_WINDOW.get()) MemoryMap.show(SHOW_IMGUI_FILE_DIALOG_WINDOW);
        if (SHOW_IMGUI_MEMORY_EDITOR_WINDOW.get()) MemoryEditor.show(SHOW_IMGUI_MEMORY_EDITOR_WINDOW);
        if (SHOW_IMGUI_MEMORY_WATCH_WINDOW.get()) MemoryWatch.show(SHOW_IMGUI_MEMORY_WATCH_WINDOW);
        if (SHOW_IMGUI_TLSF_WINDOW.get()) Tlsf.show(SHOW_IMGUI_TLSF_WINDOW);
        if (SHOW_IMGUI_COLLISION_WINDOW.get()) CollisionBox.show(SHOW_IMGUI_COLLISION_WINDOW);
        if (SHOW_IMGUI_SPRITE_RENDER_WINDOW.get()) SpriteRender.show(SHOW_IMGUI_SPRITE_RENDER_WINDOW);
        if (SHOW_IMGUI_OJECT_SLOTS_WINDOW.get()) ObjectSlots.show(SHOW_IMGUI_OJECT_SLOTS_WINDOW);
        if (SHOW_IMGUI_SMPS_WINDOW.get()) SmpsDriver.show(SHOW_IMGUI_SMPS_WINDOW);
        
        ImGui.text(String.format("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / ImGui.getIO().getFramerate(), ImGui.getIO().getFramerate()));
    }
}