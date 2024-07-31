package com.widedot.toolbox.debug.ui;

import com.widedot.toolbox.debug.util.HexUtils;
import com.widedot.toolbox.debug.util.SoundPlayerBlock;

import imgui.extension.implot.ImPlot;
import imgui.internal.ImGui;
import imgui.type.ImBoolean;
import imgui.type.ImString;

public class MeaEmulator {
	
	public static ImString input = new ImString(1024);
	public static Mea8000Device mea = new Mea8000Device();
	public static SoundPlayerBlock snd = new SoundPlayerBlock();
	
    static {
        ImPlot.createContext();
    }
    
    private static Integer[] xs = {};
    private static Integer[] ymea = {};
	
	public static void show(ImBoolean showImGui) {
		
		if (ImGui.begin("MEA8000 Emulator", showImGui)) {
			
            if (ImGui.button("Play")) {
            	byte[] data = HexUtils.hexStringToByteArray(input.toString());
            	byte[] meaSound = mea.compute(data);
            	//byte[] meaSound = SineWave.createSinWaveBuffer(440,3000);

            	if (meaSound != null) {
	            	int byteDepth = 2;
	            	int scale = 8;
	            	int length = meaSound.length/(scale*byteDepth);
            	
	            	xs   = new Integer[length];
	            	ymea = new Integer[length];
	            	int j = 0;
	            	
	            	for (int i=0; i<meaSound.length; i+=scale*byteDepth) {
	            		xs[j] = j;
	            		ymea[j] = (meaSound[i+1] << 8) | (meaSound[i] & 0xff);
	            		j++;
	            	}
	            	
	            	snd.play(meaSound);
            	}
            }
            
			ImGui.inputTextMultiline("##MEAinput", input, 600, 400);
            
            if (ImPlot.beginPlot("Audio")) {
                ImPlot.plotLine("MEA8000", xs, ymea);
                ImPlot.endPlot();
            }
            
		}
		ImGui.end();
	}

}
