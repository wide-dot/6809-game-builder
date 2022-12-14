package com.widedot.toolbox.debug.ui;

import com.widedot.toolbox.debug.Emulator;
import com.widedot.toolbox.debug.Symbols;

import imgui.ImColor;
import imgui.internal.ImGui;
import imgui.type.ImBoolean;

public class SmpsDriver {

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

//StructStart
//Smps          SmpsVar
//
//tracksStart                ; This is the beginning of all BGM track memory
//SongDACFMStart
//SongDAC         Track
//SongFMStart
//SongFM1         Track
//SongFM2         Track
//SongFM3         Track
//SongFM4         Track
//SongFM5         Track
//SongFM6         Track
//SongFM7         Track
//SongFM8         Track
//SongFM9         Track
//SongFMEnd
//SongDACFMEnd
//SongPSGStart
//SongPSG1        Track
//SongPSG2        Track
//SongPSG3        Track
//;SongPSG4        Track
//SongPSGEnd
//tracksEnd
//
//tracksSFXStart
//SFXFMStart
//SFXFM3          Track
//SFXFM4          Track
//SFXFM5          Track
//SFXFMEnd
//SFXPSGStart
//SFXPSG1         Track
//SFXPSG2         Track
//SFXPSG3         Track
//SFXPSGEnd
//tracksSFXEnd
//StructEnd
//
//SmpsVar
//
//SFXPriorityVal                 equ   0
//TempoTimeout                   equ   1        
//CurrentTempo                   equ   2
//StopMusic                      equ   3
//FadeOutCounter                 equ   4        
//FadeOutDelay                   equ   5        
//QueueToPlay                    equ   6
//SFXToPlay                      equ   7
//VoiceTblPtr                    equ   9
//SFXVoiceTblPtr                 equ   11
//FadeInFlag                     equ   13       
//FadeInDelay                    equ   14        
//FadeInCounter                  equ   15        
//_1upPlaying                    equ   16        
//TempoMod                       equ   17        
//TempoTurbo                     equ   18
//SpeedUpFlag                    equ   19        
//DACEnabled                     equ   20                
//_60HzData                      equ   21
//
//Track
//
//PlaybackControl              equ   0
//VoiceControl                 equ   1
//NoteControl                  equ   2
//TempoDivider                 equ   3
//DataPointer                  equ   4
//TranspAndVolume              equ   6
//Transpose                    equ   6
//Volume                       equ   7
//VoiceIndex                   equ   8
//VolFlutter                   equ   9
//StackPointer                 equ   10
//DurationTimeout              equ   11
//SavedDuration                equ   12
//NextData                     equ   13
//NoteFillTimeout              equ   15
//NoteFillMaster               equ   16
//ModulationPtr                equ   17
//ModulationWait               equ   19
//ModulationSpeed              equ   20
//ModulationDelta              equ   21
//ModulationSteps              equ   22
//ModulationVal                equ   23
//Detune                       equ   25
//VolTLMask                    equ   26
//PSGNoise                     equ   27
//TLPtr                        equ   28
//InstrTranspose               equ   30 
//InstrAndVolume               equ   31 
//LoopCounters                 equ   32   
//GoSubStack                   equ   42

