package com.widedot.toolbox.debug;

import com.widedot.toolbox.debug.ui.*;
import com.widedot.toolbox.mea8000.ui.MeaMainDialog;

import imgui.ImGui;
import imgui.ImGuiIO;
import imgui.app.Application;
import imgui.app.Configuration;
import imgui.flag.ImGuiBackendFlags;
import imgui.type.ImBoolean;

import java.util.HashMap;
import java.util.Map;

public class WDDebug extends Application {
	
	public static int curPid = 0;
	private static boolean attached = false;

	// Memory page configuration
	private static final int MIN_PAGE = 4;
	private static final int MAX_PAGE = 31;
	
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
    private static final ImBoolean SHOW_IMGUI_PALETTE_WINDOW = new ImBoolean(false);
    
    // Memory page windows
    private static final Map<Integer, ImBoolean> pageWindowStates = new HashMap<>();
    private static final Map<Integer, MemoryPageEditor> pageEditors = new HashMap<>();
    
    static {
    	// Initialize page windows
    	for (int page = MIN_PAGE; page <= MAX_PAGE; page++) {
    		pageWindowStates.put(page, new ImBoolean(false));
    		pageEditors.put(page, new MemoryPageEditor(page));
    	}
    }
	
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
                
                if (ImGui.beginMenu("Page"))
                {
                	for (int page = MIN_PAGE; page <= MAX_PAGE; page++) {
                		String pageLabel = String.format("Page %d ($%04X)", page, 0x10000 + ((page - 4) * 0x4000));
                		ImGui.menuItem(pageLabel, null, pageWindowStates.get(page));
                	}
                	ImGui.endMenu();
                }
                
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
                ImGui.menuItem("Palette", null, SHOW_IMGUI_PALETTE_WINDOW);
                ImGui.endMenu();
            }

            ImGui.endMainMenuBar();
            
        }

        // tools non related to process
        if (SHOW_IMGUI_FRAME_RENDER_WINDOW.get()) FrameRender.show(SHOW_IMGUI_FRAME_RENDER_WINDOW);
        if (SHOW_IMGUI_MEA_WINDOW.get()) MeaMainDialog.show(SHOW_IMGUI_MEA_WINDOW);
        if (SHOW_IMGUI_PALETTE_WINDOW.get()) Palette.show(SHOW_IMGUI_PALETTE_WINDOW);
        
        // Listening to emulator process
   		Emulator.pid = OS.getProcessId(Emulator.processName);
    	if (Emulator.pid == 0) {
       		ImGui.text("Waiting for emulator process <"+Emulator.processName+">.");
    		attached = false;
    		return;
    	}
    	// (re)attach when the target process changes
    	if (curPid != Emulator.pid) {
    		curPid = Emulator.pid;
    		Emulator.ramAddress = 0;
    		Emulator.paletteAddress = 0;
    		attached = OS.openProcess(Emulator.pid);
    	}
    	if (!attached) {
    		ImGui.text("Cannot attach to process "+Emulator.pid+".");
    		return;
    	}
    	// locate the emulated RAM once the TO8 boot screen is up
    	if (Emulator.ramAddress == 0) {
    		ImGui.text("Set DCMOTO to TO8 mode and make a hard reboot.");
    		Emulator.searchRamAddress();
    		if (Emulator.ramAddress == 0) return;
    	}
    	// locate the palette by scanning for the TO8 system palette (do it on the
    	// boot / home screen, before loading a game that overrides the palette)
    	if (Emulator.paletteAddress == 0) {
    		Emulator.searchPaletteAddress();
    		if (Emulator.paletteAddress == 0) {
    			ImGui.text("Palette not located: show the TO8 home screen (system palette).");
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
        if (SHOW_IMGUI_SMPS_WINDOW.get()) SmpsDriver.show(SHOW_IMGUI_SMPS_WINDOW);
        
        // Display memory page windows
        for (int page = MIN_PAGE; page <= MAX_PAGE; page++) {
        	if (pageWindowStates.get(page).get()) {
        		pageEditors.get(page).show(pageWindowStates.get(page));
        	}
        }
        
        ImGui.text(String.format("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / ImGui.getIO().getFramerate(), ImGui.getIO().getFramerate()));
    }
}