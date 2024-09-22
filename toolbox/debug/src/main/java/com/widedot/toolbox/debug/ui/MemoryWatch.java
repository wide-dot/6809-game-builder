package com.widedot.toolbox.debug.ui;

import java.util.ArrayList;
import java.util.HashSet;

import com.widedot.toolbox.debug.Emulator;
import com.widedot.toolbox.debug.Symbols;
import com.widedot.toolbox.debug.types.Data;
import com.widedot.toolbox.debug.types.Watch;
import com.widedot.toolbox.debug.types.WatchElem;

import imgui.flag.ImGuiInputTextFlags;
import imgui.flag.ImGuiTabBarFlags;
import imgui.internal.ImGui;
import imgui.type.ImBoolean;

public class MemoryWatch {
    
    private static Watch watch = new Watch();
    private static HashSet<Watch> watches = new HashSet<Watch>();
    
	public static void show(ImBoolean showImGui) {

   	    if (ImGui.begin("Watch", showImGui))
   	    {
	   	    if (ImGui.beginTabBar("##tabs", ImGuiTabBarFlags.None))
	   	    {
	   	        if (ImGui.beginTabItem("New watch"))
	   	        {
			   	   	// watch settings
			   	   	data("page", watch.page, true);
			   	   	if (watch.page.value.get() > 31) watch.page.value.set(31);
			   	   	data("address", watch.address, true);
			   	   	data("offset", watch.offset, true);
			   	 	
			   	 	Integer result = Emulator.get(watch);
			   	 	if (result != null) {
			   	 		watch.value.value.set(result);
			   	 		data("value", watch.value, false);
			   	   		
			   	   		ImGui.inputText("watch name", watch.label);
				   	   	if (ImGui.button("add to watches")) {
				   	   		watches.add(new Watch(watch));
				   	   	}
			   	 	}
			   	   	ImGui.endTabItem();
	   	        }
		   	   	
	   	        if (ImGui.beginTabItem("Watches"))
	   	        {
		   	   		for (Watch w : watches) {
				   	 	Integer result = Emulator.get(w);
				   	 	if (result != null) {
				   	 		w.value.value.set(result);
				   	 		ImGui.setNextItemWidth(120);
			   	   			ImGui.inputScalar(w.label.get(), Data.imType.get(w.value.type), w.value.value, 0, 0, Data.format.get(w.value.type), Data.imFlags.get(w.value.type));
				   	 	}
		   	   		}
			   	   	ImGui.endTabItem();
		   	   	}
		   	    ImGui.endTabBar();
	   	    }   
   		    ImGui.end();
   	    }
	}
	
	private static void data(String label, WatchElem we, boolean symbolFiltering) {
		
		// data type
   	   	ImGui.setNextItemWidth(55);
   	   	if (ImGui.beginCombo("##"+we+"Typ", we.type)) {
   	   		for (int n = 0; n < we.types.length; n++) {
   	   	        ImBoolean is_selected = new ImBoolean(we.type == we.types[n]);
   	   	        if (ImGui.selectable(we.types[n], is_selected)) {we.type = we.types[n]; we.refreshValue();}
   	   	        if (is_selected.get()) ImGui.setItemDefaultFocus();
   	   		}
   	   		ImGui.endCombo();
   	   	}
   	   	ImGui.sameLine();

   	   	// check if symbol filtering is enabled
   	   	if (symbolFiltering) {
   	   		ImGui.checkbox("##"+we+"Chk", we.symbolFiltering);
   	   	   	ImGui.sameLine();
   	   	} else {
   	   		we.symbolFiltering.set(false);
   	   	}
   	   	
   	   	if (we.symbolFiltering.get()) {
   	   		
   			// symbol filtering
   			ImGui.inputText(label+"##"+we+"Flt", we.symbol, ImGuiInputTextFlags.CallbackResize);

   			// count number of results
   			int i = 0; boolean exactMatch = false;
   			ArrayList<String> filterValues = new ArrayList<String>();
   			for (String key : Symbols.symbols.keySet()) {
   				if (key.contains(we.symbol.get())) {
   					i++;
   					filterValues.add(key);
   					if (key.equals(we.symbol.get())) exactMatch = true;
   				}
   			}

   			// if matches are > 1, or the only one match is not a full match : display the list
   			if (!exactMatch && (i > 1 || (i == 1 && !filterValues.get(0).equals(we.symbol.get())))) {
   				ImGui.invisibleButton("##"+we+"iBtn", 82, 10);
   	   	   	   	ImGui.sameLine();
   				ImGui.beginListBox("##"+we+"Sym");
   				for (String key : filterValues) {
   					ImBoolean is_selected = new ImBoolean(we.symbol.get() == key);
   					if (ImGui.selectable(key, is_selected)) we.symbol.set(key);
   					if (is_selected.get()) ImGui.setItemDefaultFocus();
   				}
   				ImGui.endListBox();
   			} else {
   				we.refreshValue();
   			}
   			
   	   	} else {
   	   		// if no symbol filtering, use manual address
   	   	   	ImGui.setNextItemWidth(120);
   	   	   	ImGui.inputScalar(label+"##"+we+"Lbl", Data.imType.get(we.type), we.value, 1, 1, Data.format.get(we.type), Data.imFlags.get(we.type));
   	   	}
	}
}
