package com.widedot.toolbox.mea8000.ui;

import java.util.Map;

import com.widedot.toolbox.mea8000.AudioLoader;
import com.widedot.toolbox.mea8000.SampleData;
import com.widedot.toolbox.mea8000.dsp.Formants;

import imgui.extension.imguifiledialog.ImGuiFileDialog;
import imgui.extension.imguifiledialog.callback.ImGuiFileDialogPaneFun;
import imgui.extension.imguifiledialog.flag.ImGuiFileDialogFlags;
import imgui.internal.ImGui;
import imgui.type.ImBoolean;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class MeaMainDialog {

	// file dialog
	private static String lastDirectory = ".";
    private static ImGuiFileDialogPaneFun callback = new ImGuiFileDialogPaneFun() {
        @Override
        public void accept(String filter, long userDatas, boolean canContinue) {
            ImGui.text("Filter: " + filter);
        }
    };

	private static Map<String, String> selection = null;
	private static String inputPathName = null;
	
	private static float[] audioIn = null;

	public static String show(ImBoolean showImGui) {

		inputPathName = null;
		
		if (ImGui.begin("MEA8000", showImGui)) {
				
			// File dialog
			if (ImGui.button("Load")) {
				ImGuiFileDialog.openModal("browse-key", "Choose File", ".wav", lastDirectory, callback, 250, 1, 42,
						ImGuiFileDialogFlags.None);
			}
			ImGui.sameLine();

			if (ImGuiFileDialog.display("browse-key", ImGuiFileDialogFlags.None, 200, 400, 800, 600)) {
				if (ImGuiFileDialog.isOk()) {
					selection = ImGuiFileDialog.getSelection();
					lastDirectory = ImGuiFileDialog.getCurrentPath()+"/";
				}
				ImGuiFileDialog.close();

				// Open the wav file specified as the first argument
				if (selection != null && !selection.isEmpty()) {
					
					inputPathName = selection.values().stream().findFirst().get();
					log.debug("Selected file: {}", inputPathName);
					audioIn = AudioLoader.loadf(inputPathName);
					Formants.compute(audioIn);
					AudioSpectrum.compute(Formants.xf, Formants.yf, Formants.xCurves, Formants.yCurves);
				}

			}
			
			// Audio Spectrum
			if (ImGui.button("Sample Data")) {
				AudioSpectrum.compute(SampleData.p, SampleData.n, SampleData.ampl, SampleData.fm, SampleData.bw);
			}
			AudioSpectrum.show(new ImBoolean(true));
		}

		ImGui.end();
		return inputPathName;
	}
}
