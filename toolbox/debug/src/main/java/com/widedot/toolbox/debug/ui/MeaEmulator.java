package com.widedot.toolbox.debug.ui;

import java.io.File;
import java.util.Arrays;
import java.util.Map;

import com.widedot.toolbox.debug.util.HexUtils;
import com.widedot.toolbox.debug.util.SoundPlayerBlock;
import com.widedot.toolbox.debug.util.WavFile;

import imgui.extension.imguifiledialog.ImGuiFileDialog;
import imgui.extension.imguifiledialog.callback.ImGuiFileDialogPaneFun;
import imgui.extension.imguifiledialog.flag.ImGuiFileDialogFlags;
import imgui.extension.implot.ImPlot;
import imgui.internal.ImGui;
import imgui.type.ImBoolean;
import imgui.type.ImString;

public class MeaEmulator {

	// file dialog
	private static String lastDirectory = ".";
	private static ImGuiFileDialogPaneFun callback = new ImGuiFileDialogPaneFun() {
		@Override
		public void paneFun(String filter, long userDatas, boolean canContinue) {
			ImGui.text("Filter: " + filter);
		}
	};
	private static Map<String, String> selection = null;

	private static ImString input = new ImString(0x10000);
	private static Mea8000Device mea = new Mea8000Device();
	private static SoundPlayerBlock snd = new SoundPlayerBlock();
	private static byte[] data;
	private static byte[] meaSound;
	private static byte[] refSound;
	private static Integer[] xmea = {};
	private static Integer[] ymea = {};
	private static Integer[] xref = {};
	private static Integer[] yref = {};

	static {
		ImPlot.createContext();

		// Bonjour !
		input.set("1A 3C\r\n" + "44 B6 28 10 C4 2F 32 B0 C5 AE 2B A0\r\n"
				+ "C4 B3 34 A0 55 AD 6E A2 5B AD 7E A4 5A A4 9E 26\r\n"
				+ "59 A4 A6 2A 59 A5 9E AC 45 AC 96 A7 14 A8 7E A3\r\n"
				+ "55 AE 66 A0 20 B0 56 BE 11 B3 56 B5 1A B3 56 36\r\n"
				+ "45 B5 56 30 45 B7 57 30 05 B6 57 30 15 B3 56 B1\r\n"
				+ "58 B4 5E 31 54 B2 5E 3D 96 91 65 BD 96 B0 55 3C\r\n"
				+ "97 B0 55 3E 9A AF 4C BF 9A AE 4C 3F A6 AD 44 3E\r\n"
				+ "A5 AC 4B A0 95 AE 4B 30 95 AD 4B 30 91 AE 53 30\r\n"
				+ "50 AC 53 30 80 AF 53 20 D8 AE 5B 20 A6 AE 5B A0\r\n"
				+ "69 AF 63 A0 AD AE 7C 20 69 AE 84 A0 24 AD D4 B0\r\n"
				+ "51 B0 F4 30 32 90 C4 30 70 B1 C4 B0 64 B3 B4 B0\r\n" + "62 B3 8B B0 62 B3 88 30");
	}

	public static void show(ImBoolean showImGui) {

		if (ImGui.begin("MEA8000 Emulator", showImGui)) {
			try {

				if (ImGui.button("Load")) {
					ImGuiFileDialog.openModal("browse-key", "Choose File", ".wav", lastDirectory, callback, 250, 1, 42,
							ImGuiFileDialogFlags.None);
				}
				ImGui.sameLine();

				if (ImGuiFileDialog.display("browse-key", ImGuiFileDialogFlags.None, 200, 400, 800, 600)) {
					if (ImGuiFileDialog.isOk()) {
						selection = ImGuiFileDialog.getSelection();
						lastDirectory = ImGuiFileDialog.getCurrentPath();
					}
					ImGuiFileDialog.close();

					// Open the wav file specified as the first argument

					if (selection != null && !selection.isEmpty()) {

						File file = new File(selection.values().stream().findFirst().get());
						WavFile wavFile = WavFile.openWavFile(file);

						// Display information about the wav file
						wavFile.display();

						// Get the number of audio channels in the wav file
						int numChannels = wavFile.getNumChannels();
						if (numChannels != 1) {
							throw new Exception("Wav file should be mono.");
						}

						// Create a buffer
						int[] buffer = new int[(int) wavFile.getNumFrames()];
						wavFile.readFrames(buffer, (int) wavFile.getNumFrames());
						yref = Arrays.stream(buffer).boxed().toArray(Integer[]::new);
						xref = new Integer[yref.length];
						for (int i = 0; i < yref.length; i++) {
							xref[i] = i;
						}
						ImPlot.fitNextPlotAxes();

						// Close the wavFile
						wavFile.close();
					}

				}

				ImGui.sameLine();
				if (ImGui.button("Encode")) {
					data = HexUtils.hexStringToByteArray(input.toString());
					meaSound = mea.compute(data);
					// meaSound = SineWave.createSinWaveBuffer(440,3000);

					int byteDepth = 2;
					int scale = 8;
					int length = meaSound.length / (scale * byteDepth);

					xmea = new Integer[length];
					ymea = new Integer[length];
					int j = 0;

					for (int i = 0; i < meaSound.length; i += scale * byteDepth) {
						xmea[j] = j;
						ymea[j] = (meaSound[i + 1] << 8) | (meaSound[i] & 0xff);
						j++;
					}
					ImPlot.fitNextPlotAxes();
				}

				if (refSound != null) {
					ImGui.sameLine();
					if (ImGui.button("Play ref.")) {
						snd.play(refSound);
					}
				}

				if (meaSound != null) {
					ImGui.sameLine();
					if (ImGui.button("Play synth.")) {
						snd.play(meaSound);
					}
				}

				ImGui.inputTextMultiline("##MEAinput", input, 600, 400);

				if (ImPlot.beginPlot("Audio")) {
					ImPlot.plotLine("MEA8000", xmea, ymea);
					ImPlot.plotLine("Reference", xref, yref);
					ImPlot.endPlot();
				}
			} catch (Exception e) {
				System.err.println(e);
			}
		}

		ImGui.end();

	}

}
