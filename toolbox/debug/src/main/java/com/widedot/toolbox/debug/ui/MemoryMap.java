package com.widedot.toolbox.debug.ui;

import imgui.extension.imguifiledialog.ImGuiFileDialog;
import imgui.extension.imguifiledialog.callback.ImGuiFileDialogPaneFun;
import imgui.extension.imguifiledialog.flag.ImGuiFileDialogFlags;
import imgui.flag.ImGuiCond;
import imgui.internal.ImGui;
import imgui.type.ImBoolean;
import lombok.extern.slf4j.Slf4j;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.Map;
import java.util.stream.Stream;

import com.widedot.toolbox.debug.Symbols;

@Slf4j
	public class MemoryMap {

	    private static Map<String, String> selection = null;
	    private static String delSelection = null;
	    private static String delDialog = null;
	    private static HashMap<String, ImBoolean> openedDialogs = new HashMap<String, ImBoolean>();
	    
	    private static String lastDirectory = ".";
	    private static ImGuiFileDialogPaneFun callback = new ImGuiFileDialogPaneFun() {
	        @Override
	        public void paneFun(String filter, long userDatas, boolean canContinue) {
	            ImGui.text("Filter: " + filter);
	        }
	    };

	    public static void show(ImBoolean showImGui) {
	        ImGui.setNextWindowSize(800, 200, ImGuiCond.Once);
	        ImGui.setNextWindowPos(ImGui.getMainViewport().getPosX() + 100, ImGui.getMainViewport().getPosY() + 100, ImGuiCond.Once);
	        if (ImGui.begin("Memory Map", showImGui)) {

	            if (ImGui.button("Add .map files")) {
	                ImGuiFileDialog.openModal("browse-key", "Choose many File", ".map", lastDirectory, callback, 250, 0, 42, ImGuiFileDialogFlags.None);
	            }
	            ImGui.sameLine();
	            
	            if (ImGuiFileDialog.display("browse-key", ImGuiFileDialogFlags.None, 200, 400, 800, 600)) {
	                if (ImGuiFileDialog.isOk()) {
	                    selection = ImGuiFileDialog.getSelection();
	                    lastDirectory = ImGuiFileDialog.getCurrentPath();
	                    
	    	        	for (String key : selection.keySet()) {
	    	        		Symbols.addMap(selection.get(key));
	    	        	}
	                }
	                ImGuiFileDialog.close();
	            }
	            
	            if (ImGui.button("Scan folder")) {
	                ImGuiFileDialog.openDialog("browse-folder-key", "Choose Folder", null, lastDirectory, "", 1, 7, ImGuiFileDialogFlags.None);
	            }
	            ImGui.sameLine();
	            
	            if (ImGuiFileDialog.display("browse-folder-key", ImGuiFileDialogFlags.None, 200, 400, 800, 600)) {
	                if (ImGuiFileDialog.isOk()) {
	                    selection = ImGuiFileDialog.getSelection();
	                    
	    	        	for (String key : selection.keySet()) {
		        			//try (Stream<Path> walkStream = Files.walk(Paths.get(selection.get(key)))) {
		        			try (Stream<Path> walkStream = Files.walk(Paths.get(selection.get(key).substring(0,selection.get(key).lastIndexOf("\\"))))) { // fix for a bug in dir selection
		        			    walkStream.filter(p -> p.toFile().isFile()).forEach(f -> {
		        			        if (f.toString().endsWith(".map")) {
		        						log.info("Load symbols <"+f.toString()+">");
		        			        	Symbols.addMap(f.toString());
		        			        }
		        			    });
		        			} catch(Exception e) {
		        				log.error("Error reading directory "+selection.get(key));
		        			}
	    	        	}
	                }
	                ImGuiFileDialog.close();
	            }
	            
	            if (ImGui.button("Clear list")) {
	            	Symbols.maps.clear();
	            }
	        }

	        // display map files
	        delSelection = null;
        	for (String key : Symbols.maps.keySet()) {
        		
        		// delete button
        		if (ImGui.button("-##"+key)) {
        			delSelection = key;
        		}
       			ImGui.sameLine();
       			
       			// display file content button
       			delDialog = null;
       			for (String show : openedDialogs.keySet()) {
       				if (openedDialogs.get(show).get() == false) {
       					delDialog = show;
       				}
       			}
            	if (delDialog != null) openedDialogs.remove(delDialog);
       			
       			if (ImGui.button(key)) openedDialogs.put(key, new ImBoolean(true));
       			
       			if (openedDialogs.containsKey(key) && openedDialogs.get(key).get()) {
	   				ImGui.begin(key, openedDialogs.get(key));
	   				for (String key2 : Symbols.maps.get(key).keySet()) {
	        			ImGui.text(key2+" "+Symbols.maps.get(key).get(key2));
	   				}
	            	ImGui.end();
       			}
        	}
        	
        	// remove deleted file from list
        	if (delSelection != null) Symbols.maps.remove(delSelection);
        	
		    ImGui.end();
	    }
	}