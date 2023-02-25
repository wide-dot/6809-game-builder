package com.widedot.toolbox.debug.ui;

import com.widedot.toolbox.debug.Emulator;
import com.widedot.toolbox.debug.Symbols;

import imgui.ImColor;
import imgui.ImVec2;
import imgui.internal.ImGui;
import imgui.type.ImBoolean;

public class ObjectSlots {

	private static final int slotWidth = 120;
	private static final int slotHeight = 15;
	private static final int slotPerLine = 4;
	
	public static void show(ImBoolean showImGui) {
		
        if (ImGui.begin("Object Slots", showImGui)) {
        	String objectTable = Symbols.symbols.get("Dynamic_Object_RAM");
	   	 	String objectSizeStr = Symbols.symbols.get("object_size");
	   	 	String nbDynamicObjectsStr = Symbols.symbols.get("nb_dynamic_objects");
	   	 	if (objectTable==null || objectSizeStr==null || nbDynamicObjectsStr==null) {ImGui.end(); return;}
	   	 	
	   	 	Long result = Emulator.getAbsoluteAddress(1, objectTable);
	   	 	int objectSize = Integer.parseInt(objectSizeStr, 16);
	   	 	int nbDynamicObjects = Integer.parseInt(nbDynamicObjectsStr, 16);
	   	 	if (result==null) {ImGui.end(); return;}
	   	 	
	   	 	String[] objectName = getObjectName();
        
        	 for (int i = 0; i < nbDynamicObjects; i++) {
                 if (i%slotPerLine != 0) ImGui.sameLine();
                 ImGui.pushID(i);
                 Integer objectId = Emulator.get(result+objectSize*i, 1);
                 if (objectId == 0) {
                	 ImGui.getWindowDrawList().addRectFilled(ImGui.getCursorScreenPosX(), ImGui.getCursorScreenPosY(), ImGui.getCursorScreenPosX()+slotWidth, ImGui.getCursorScreenPosY()+slotHeight, ImColor.intToColor(48,48,48));
                	 ImGui.selectable(objectName[objectId], false, 0, slotWidth, slotHeight);
                 } else {
                	 ImGui.getWindowDrawList().addRectFilled(ImGui.getCursorScreenPosX(), ImGui.getCursorScreenPosY(), ImGui.getCursorScreenPosX()+slotWidth, ImGui.getCursorScreenPosY()+slotHeight, ImColor.intToColor(41,74,122));
                	 if (ImGui.selectable(objectName[objectId], false, 0, slotWidth, slotHeight)) {
                		 
                	 }
                 }
                 {
                	 // select action
                 }
                 ImGui.popID();
        	 }
        	 
    	    ImGui.end();
        }
	}
	
	public static final String _EMPTY_STRING = "";
	
	public static String[] getObjectName() {
		int size = 256;
		String objectName[] = new String[size];
		for (String key : Symbols.symbols.keySet()) {
			if (key.startsWith("ObjID_")) {
				objectName[Integer.parseInt(Symbols.symbols.get(key), 16)] = key.substring(6, key.length());
			}
		}
		
		for (int i = 0; i < size; i++) {
			if (objectName[i] == null) {
				objectName[i] = _EMPTY_STRING;
			}
		}
		return objectName;
	}
}
