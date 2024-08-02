package com.widedot.toolbox.debug.ui;

import java.io.File;
import java.util.Arrays;
import java.util.Map;

import com.widedot.toolbox.debug.util.HexUtils;
import com.widedot.toolbox.debug.util.Mea8000Device;
import com.widedot.toolbox.debug.util.SoundPlayerBlock;
import com.widedot.toolbox.debug.util.WavFile;

import funkatronics.code.tactilewaves.dsp.FormantExtractor;
import funkatronics.code.tactilewaves.dsp.PitchProcessor;
import funkatronics.code.tactilewaves.dsp.WaveFrame;
import funkatronics.code.tactilewaves.io.WaveFormat;
import imgui.extension.imguifiledialog.ImGuiFileDialog;
import imgui.extension.imguifiledialog.callback.ImGuiFileDialogPaneFun;
import imgui.extension.imguifiledialog.flag.ImGuiFileDialogFlags;
import imgui.extension.implot.ImPlot;
import imgui.internal.ImGui;
import imgui.type.ImBoolean;
import imgui.type.ImString;
import lombok.extern.slf4j.Slf4j;

@Slf4j
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
	
	private static WavFile wavFile;

	private static ImString input = new ImString(0x10000);
	private static Mea8000Device mea = new Mea8000Device();
	private static SoundPlayerBlock snd = new SoundPlayerBlock();
	private static byte[] data;
	private static byte[] meaSound;
	private static byte[] refSound;
	private static float[] refData;
	private static Double[] xmea = {};
	private static Integer[] ymea = {};
	private static Double[] xref = {};
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

				// LOAD FILE
				// -------------------------------------------------------------
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
						wavFile = WavFile.openWavFile(file);

						// Display information about the wav file
						wavFile.display();

						// Get the number of audio channels in the wav file
						int numChannels = wavFile.getNumChannels();
						if (numChannels != 1) {
							throw new Exception("Wav file should be mono.");
						}

						// Create a buffer for plots and a buffer for wav playing
						int numFrames = (int) wavFile.getNumFrames();
						int[] buffer = new int[numFrames];
						wavFile.readFrames(buffer, numFrames);
						
						int scale = 16;
						double rate = scale * 1.0/wavFile.getSampleRate();
						int length = (int) Math.ceil((double)numFrames / scale);

						yref = new Integer[length];
						xref = new Double[length];
						int j = 0;
						
						for (int i = 0; i < numFrames; i += scale) {
							xref[j] = j*rate;
							yref[j] = buffer[i];
							j++;
						}
						
						ImPlot.fitNextPlotAxes();
						
						// Create a buffer for wav playing
						j = 0;
						refSound = new byte[numFrames * 2];
						refData = new float[numFrames];
						for (int i=0; i<numFrames; i++) {
							refSound[j++] = (byte) (buffer[i] & 0xff);
							refSound[j++] = (byte) ((buffer[i] >> 8) & 0xff);
							refData[i] = (float) buffer[i];
							
						}

						// Close the wavFile
						wavFile.close();
					}

				}

				// PLAY REF
				// -------------------------------------------------------------
				if (refSound != null) {
					ImGui.sameLine();
					if (ImGui.button("Play ref.")) {
						snd.play(refSound, (int) wavFile.getSampleRate(), 16);
					}
				}
				
				// ENCODE
				// -------------------------------------------------------------
				ImGui.sameLine();
				if (ImGui.button("Encode")) {
					
					float samples8ms = (float) ((wavFile.getSampleRate()*8.0)/1000.0);
					WaveFormat wFormat = new WaveFormat(WaveFormat.ENCODING_PCM_SIGNED, false, (int) wavFile.getSampleRate(), 16, 1);
					
					for (float i=samples8ms; i<refData.length; i+=samples8ms/16.0) {
						WaveFrame wFrame = new WaveFrame(Arrays.copyOfRange(refData, 0, (int)i), wFormat);
						PitchProcessor pp = new PitchProcessor();
						pp.process(wFrame);
						float pitch = (float) wFrame.getFeature("Pitch");
						if (pitch > 0.0 && pitch < 512.0) {
							log.info("WaveFrame: 0-{} Pitch: {}Hz", i, pitch);
							break;
						}
						
					}
					
					int frame = 0;
					for (float i=0; i<refData.length; i+=samples8ms) {
						WaveFrame wFrame = new WaveFrame(Arrays.copyOfRange(refData, (int)i, (int)(i+samples8ms)), wFormat);
						FormantExtractor fe = new FormantExtractor(20);
						fe.process(wFrame);
						log.info("Frame: {} Formant Freq: {}", frame, wFrame.getFeature("Formants Frequency"));
						log.info("Frame: {} Formant Band: {}", frame, wFrame.getFeature("Formants Bandwidth"));
						frame++;
					}
				}
				
				// DECODE
				// -------------------------------------------------------------
				ImGui.sameLine();
				if (ImGui.button("Decode")) {
					data = HexUtils.hexStringToByteArray(input.toString());
					meaSound = mea.compute(data);
					// meaSound = SineWave.createSinWaveBuffer(440,3000);

					int byteDepth = 2;
					int scale = 16;
					double rate = scale * 1.0/Mea8000Device.SAMPLERATE;
					int length = (int) Math.ceil((double)meaSound.length / (scale * byteDepth));

					xmea = new Double[length];
					ymea = new Integer[length];
					int j = 0;

					for (int i = 0; i < meaSound.length; i += scale * byteDepth) {
						xmea[j] = j*rate;
						ymea[j] = (meaSound[i + 1] << 8) | (meaSound[i] & 0xff);
						j++;
					}
					ImPlot.fitNextPlotAxes();
				}

				// PLAY SYNTH
				// -------------------------------------------------------------
				if (meaSound != null) {
					ImGui.sameLine();
					if (ImGui.button("Play synth.")) {
						snd.play(meaSound, Mea8000Device.SAMPLERATE, Mea8000Device.BITDEPTH);
					}
				}

				// PLOT
				// -------------------------------------------------------------
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
