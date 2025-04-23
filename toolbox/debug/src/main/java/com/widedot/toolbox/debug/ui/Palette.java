package com.widedot.toolbox.debug.ui;

import java.io.IOException;
import com.widedot.toolbox.debug.types.PaletteBufferImage;

import imgui.ImVec2;
import imgui.extension.imguifiledialog.ImGuiFileDialog;
import imgui.extension.imguifiledialog.callback.ImGuiFileDialogPaneFun;
import imgui.extension.imguifiledialog.flag.ImGuiFileDialogFlags;
import imgui.internal.ImGui;
import imgui.type.ImBoolean;

public class Palette {

	private static ImVec2 vMin;
	private static int SIZE = 64;
	private static int SCALE = 16;
	
	public static ImBoolean workingChk = new ImBoolean(true);
	public static PaletteBufferImage image = new PaletteBufferImage(SIZE);
	
    private static String lastDirectory = ".";
    private static String selection = null;
	private static String outputPathName = null;
    private static ImGuiFileDialogPaneFun callback = new ImGuiFileDialogPaneFun() {
        @Override
        public void accept(String filter, long userDatas, boolean canContinue) {
            ImGui.text("Filter: " + filter);
        }
    };
	
	public static void show(ImBoolean showImGui) {
		
        if (ImGui.begin("Thomson palette", showImGui)) {
        	
            if (ImGui.button("Save As PNG")) {
            	ImGuiFileDialog.openModal("browse-key", "Choose a File", ".png", lastDirectory, callback, 250, 0, 42, ImGuiFileDialogFlags.None);
            }
            
            if (ImGuiFileDialog.display("browse-key", ImGuiFileDialogFlags.None, 200, 400, 800, 600)) {
    			if (ImGuiFileDialog.isOk()) {
    				lastDirectory = ImGuiFileDialog.getCurrentPath()+"/";
    				selection = lastDirectory+ImGuiFileDialog.getCurrentFileName();
    				
        			if (selection != null && !selection.isEmpty()) {
        				outputPathName = selection;
    	                if (!outputPathName.endsWith(".png")) {
    	                	outputPathName += ".png";
    	                }
    	                
                        try {
    						image.saveAsPNG(outputPathName);
    					} catch (IOException e) {
    						e.printStackTrace();
    					}
    	        	}
    			}
    			ImGuiFileDialog.close();
            }
            
			vMin = ImGui.getWindowContentRegionMin();
			vMin.x += ImGui.getWindowPos().x;
			vMin.y += ImGui.getWindowPos().y+24;
			
			ImGui.getWindowDrawList().addImage(image.get(SCALE), vMin.x, vMin.y, vMin.x+image.getWidth(), vMin.y+image.getHeight());
    	    ImGui.end();
        }
	}
}