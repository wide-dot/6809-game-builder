package com.widedot.toolbox.debug.ui;

import com.widedot.toolbox.debug.util.HexUtils;
import com.widedot.toolbox.debug.util.SoundPlayerBlock;

import imgui.internal.ImGui;
import imgui.type.ImBoolean;
import imgui.type.ImString;

public class MeaEmulator {
	
	public static ImString input = new ImString(1024);
	public static Mea8000Device mea = new Mea8000Device();
	public static SoundPlayerBlock snd = new SoundPlayerBlock();
	
	public static void show(ImBoolean showImGui) {
		
		if (ImGui.begin("MEA8000 Emulator", showImGui)) {
			
            if (ImGui.button("Play")) {
            	byte[] data = HexUtils.hexStringToByteArray(input.toString());
            	byte[] sound = mea.compute(data);
            	//byte[] sound = SineWave.createSinWaveBuffer(440,3000);
            	snd.play(sound);
            }
            
			ImGui.inputTextMultiline("##MEAinput", input, 400, 400);
		}
		ImGui.end();
	}

}
