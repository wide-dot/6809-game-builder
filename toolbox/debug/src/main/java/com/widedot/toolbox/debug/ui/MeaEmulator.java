package com.widedot.toolbox.debug.ui;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.Map;

import com.widedot.toolbox.debug.DataUtil;
import com.widedot.toolbox.debug.util.HexUtils;
import com.widedot.toolbox.debug.util.Mea8000Device;
import com.widedot.toolbox.debug.util.SoundPlayerBlock;
import com.widedot.toolbox.debug.util.WavFile;

import funkatronics.code.tactilewaves.dsp.FormantExtractor;
import funkatronics.code.tactilewaves.dsp.PitchProcessor;
import funkatronics.code.tactilewaves.dsp.WaveFrame;
import funkatronics.code.tactilewaves.dsp.toolbox.Window;
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
	
	private static String inputPathName;
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
		input.set("00 B8 3C\r\n"
		        + "44 B6 28 10" + " 3C " + "C4 2F 32 B0 C5 AE 2B A0\r\n"
				+ "C4 B3 34 A0 55 AD 6E A2 5B AD 7E A4 5A A4 9E 26\r\n"
				+ "59 A4 A6 2A 59 A5 9E AC 45 AC 96 A7 14 A8 7E A3\r\n"
				+ "55 AE 66 A0 20 B0 56 BE 11 B3 56 B5 1A B3 56 36\r\n"
				+ "45 B5 56 30 45 B7 57 30 05 B6 57 30 15 B3 56 B1\r\n"
				+ "58 B4 5E 31 54 B2 5E 3D 96 91 65 BD 96 B0 55 3C\r\n"
				+ "97 B0 55 3E 9A AF 4C BF 9A AE 4C 3F A6 AD 44 3E\r\n"
				+ "A5 AC 4B A0 95 AE 4B 30 95 AD 4B 30 91 AE 53 30\r\n"
				+ "50 AC 53 30 80 AF 53 20 D8 AE 5B 20 A6 AE 5B A0\r\n"
				+ "69 AF 63 A0 AD AE 7C 20 69 AE 84 A0 24 AD D4 B0\r\n"
				+ "51 B0 F4 30 32 90 C4 30 70 B1 C4 B0 64 B3 B4 B0\r\n"
				+ "62 B3 8B B0 62 B3 88 30");
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

						inputPathName = selection.values().stream().findFirst().get();
						File file = new File(inputPathName);
						wavFile = WavFile.openWavFile(file);

						// Display information about the wav file
						wavFile.display();

						// Get the number of audio channels in the wav file
						int numChannels = wavFile.getNumChannels();
						if (numChannels != 1) {
							throw new Exception("Wav file should be mono.");
						}
						
						// Check bitdepth - TODO enable a val <> 16 bits
						int bitdepth = wavFile.getValidBits();
						if (bitdepth != 16) {
							throw new Exception("Wav file should be 16bits.");
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
						int offset = (int) ((wavFile.getSampleRate()*8.0)/1000.0); // 8ms
						j = 0;
						refSound = new byte[numFrames * 2];
						refData = new float[numFrames + offset];
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
					
					float sampleDuration = (float) ((wavFile.getSampleRate()*8.0)/1000.0); // 8ms
					float sampleWindow = (float) ((wavFile.getSampleRate()*24.0)/1000.0);  // 24ms
					WaveFormat wFormat = new WaveFormat(WaveFormat.ENCODING_PCM_SIGNED, false, (int) wavFile.getSampleRate(), 16, 1);
					WaveFrame wFrame;
					FormantExtractor fe;
					PitchProcessor pp = new PitchProcessor();
					byte[] encodedData = new byte[2]; // 2 bytes for blank header
					int frame, formants;
					float rms, lastRms = 0;
					float pitch, lastPitch = 0;
					float amplThreshold = 8; // minimal amplitude of 0.008 for MEA8000

					frame = 0;
					for (float i=0; i<refData.length; i+=sampleDuration) {
						
						// process audio with a window of 25ms and a step of 8ms 
						wFrame = new WaveFrame(Arrays.copyOfRange(refData, (int)i, (int)(i+sampleWindow)), wFormat);
						wFrame.addFeature("Frame", frame);
						
						// find frame amplitude
						rms = 0;
						//float[] x = Window.hamming(wFrame.getSamples());

						//float[] x = wFrame.getSamples();
						//for (int j = (int) sampleDuration; j < sampleDuration*2; j++) {
						//	rms += x[j]*x[j];
						//}
						//rms = (float) (Math.sqrt(rms/sampleDuration));
						//rms = (float) (rms / 32.768 / 2.0);
						
						float[] x = wFrame.getSamples();
						for (int j = (int) (sampleDuration*0.5); j < (int) (sampleDuration*1.0); j++) {
							if (Math.abs(x[j]) > rms) {
								rms = Math.abs(x[j]);
							}
						}
						rms = (float) (rms * 0.5 / 32.768); // TODO: replace mult by QUANT
						
						log.info("AMPLITUDE: {}", rms);
						if (rms < amplThreshold) {
							rms = 0;
						}
						wFrame.addFeature("Amplitude", rms);
						
						if (rms == 0) {
							
							wFrame.addFeature("Pitch", (float)-1);
							wFrame.addFeature("Formants Frequency", new float[0]);
							wFrame.addFeature("Formants Bandwidth", new float[0]);
							
						} else {
							
							// find frame pitch
							pp.process(wFrame);
							
							// TODO: make optional
							if ((float) wFrame.getFeature("Pitch") == -1 && lastPitch >= 0) {
								wFrame.removeFeature("Pitch");
								wFrame.addFeature("Pitch", lastPitch);
							}
							
							// search frame formants
							// TODO: check against preset MEA8000 values, and select best match freq ONLY
							formants=4;
							do {
								wFrame.removeFeature("Formants Frequency");
								wFrame.removeFeature("Formants Bandwidth");
								fe = new FormantExtractor(formants);
								fe.process(wFrame);
								formants++;
							} while (((float[]) wFrame.getFeature("Formants Frequency")).length < 4 );
						}
						
						// MEA8000 encoding
						encodedData = encodeMEA8000Frame(encodedData, wFrame, lastPitch, lastRms);
						
						// get a track of last known pitch, -1 value is noise/not found
						pitch = (float) wFrame.getFeature("Pitch");
						if (pitch != -1) {
							lastPitch = pitch;
						}
						
						// get track of last amplitude, a silence will send a STOP
						lastRms = (float) wFrame.getFeature("Amplitude");
						
						frame++;
					}
					
					// add end marker of 4 null bytes
					encodedData = Arrays.copyOf(encodedData, encodedData.length+4);
					
					// update header with total length
					encodedData[0] = (byte) ((encodedData.length & 0xff00) >> 8);
					encodedData[1] = (byte) (encodedData.length & 0xff);
					
					input.set(DataUtil.bytesToHex(encodedData)+"\r\n");					
					Files.write(Path.of(inputPathName+".mea"), encodedData);
					
					log.info("Encoding done !");
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
	
	public static byte[] encodeMEA8000Frame(byte[] encodedData, WaveFrame wFrame, float lastPitch, float lastAmpl) {
		
		int frame = (int) wFrame.getFeature("Frame");
		float pitch = (float) wFrame.getFeature("Pitch");
		float ampl = (float) wFrame.getFeature("Amplitude");
		float[] formFreqs = (float[]) wFrame.getFeature("Formants Frequency");
		float[] formBands = (float[]) wFrame.getFeature("Formants Bandwidth");
		
		log.debug("Frame: {} - Ampl: {} Pitch: {}Hz Formant Freq: {} Formant Band: {}",
				frame,
				ampl,
				pitch,
				formFreqs,
				formBands);
		     
		byte pitchData;
		byte[] frameData = new byte[4];
		boolean newPitch = false;
		int val, delta, maxDelta;
		
        // Pitch variation
        // ---------------------------------------------------------------------
		// TODO: (data size optimisation) a sequence of frames could begin without a detected pitch
		// should make a pitch detection against all following frames until one is detected
		// it would reduce the number of frame groups and save a few bytes of final data
		
		int deltaPitch = (int) Math.floor(pitch-lastPitch);
		if (frame == 0 || lastAmpl == 0 || (pitch != -1 && Math.abs(deltaPitch) > 15)) {
			newPitch = true;
			// set previous frame amplitude to zero
			if (encodedData.length>0) {
				encodedData[encodedData.length-2] = (byte) (encodedData[encodedData.length-2] & 0b11111000);
				encodedData[encodedData.length-1] = (byte) (encodedData[encodedData.length-1] & 0b01111111);
			}
		}
		
		if (pitch == 0 || pitch >= 510+2) {
			log.info("Frame: {} - Out of range Pitch of {}Hz", frame, pitch);
			pitch = -1;
			wFrame.removeFeature("Pitch");
			wFrame.addFeature("Pitch", pitch);
		}
		
		if (newPitch && pitch == -1) {
			log.info("Frame: {} - First frame of new group has no pitch, default to 0Hz", frame);
			pitch = 0;
			wFrame.removeFeature("Pitch");
			wFrame.addFeature("Pitch", pitch);
		}
		
		// encode start pitch
		pitchData = (byte) (pitch/2.0);
		
		// encode delta pitch
		if (pitch == -1) {
			frameData[3] = (byte) (frameData[3] | (byte) (Mea8000Device.PITCH_NOISE)); // noise setting
		} else {
			
			val = Mea8000Device.PITCH_ZERO;
			if (!newPitch) {
		    	for (int j = 0; j < Mea8000Device.PITCH_TABLE.length; j++) {
		    		if (deltaPitch ==  Mea8000Device.PITCH_TABLE[j]) {
		    			val = j;
		    			break;
		    		}
		    	}
			}
	    	
	    	frameData[3] = (byte) (frameData[3] | (byte) (val & 0b11111));
		}
		
		// Amplitude
		// ---------------------------------------------------------------------
			
	    // match preset value, and set index
        val = 0;
        delta = 0;
        maxDelta = Integer.MAX_VALUE;
        
    	for (int j = 0; j < Mea8000Device.AMPL_TABLE.length; j++) {
    		delta = Math.abs(Mea8000Device.AMPL_TABLE[j] - (int)ampl);
    		if (delta < maxDelta) {
    			val = j;
    			maxDelta = delta;
    		}
    	}
        
    	frameData[2] = (byte) (frameData[2] | (byte) ((val >> 1) & 0b111));
    	frameData[3] = (byte) (frameData[3] | (byte) ((val & 0b1) << 7));
		
    	// Skip Frequencies analysis if silence
    	// at runtime, a ampl will throw a STOP command, this frame will be skipped
    	if (ampl > 0) {
    	
			// Frequency
			// ---------------------------------------------------------------------
			
			// set default values if less than expected values
	        for(int i = formFreqs.length; i < 3; i++) {
	        	formFreqs[i] = Mea8000Device.FM_TABLES[i][0];
	        }
	        
	        // match preset values, and set indexes
	        for(int i = 0; i < 3; i++) {
	            val = 0;
	            delta = 0;
	            maxDelta = Integer.MAX_VALUE;
	            
	        	for (int j = 0; j < Mea8000Device.FM_TABLES[i].length; j++) {
	        		delta = Math.abs((int) formFreqs[i] - Mea8000Device.FM_TABLES[i][j]);
	        		if (delta < maxDelta) {
	        			val = j;
	        			maxDelta = delta;
	        		}
	        	}
	        	
	        	if (i == 0) {
	        		frameData[2] = (byte) (frameData[2] | (byte) ((val & 0b11111) << 3));
	        	} else if (i == 1) {
	        		frameData[1] = (byte) (frameData[1] | (byte) (val & 0b11111));
	        	} else if (i == 2) {
	        		frameData[1] = (byte) (frameData[1] | (byte) ((val & 0b111) << 5));
	        	} else {
	        		log.error("Out of range when encoding frequencies.");
	        	}
	        }
	        
			// Bandwidth
			// ---------------------------------------------------------------------
			
			// set default values if less than expected values (4 freq/band)
	        for(int i = formBands.length; i < 4; i++) {
	        	formBands[i] = Mea8000Device.BW_TABLE[0];
	        }
	        
	        // match preset values, and set indexes
	        for(int i = 0; i < 4; i++) {
	            val = 0;
	            delta = 0;
	            maxDelta = Integer.MAX_VALUE;
	            
	        	for (int j = 0; j < Mea8000Device.BW_TABLE.length; j++) {
	        		delta = Math.abs((int) formBands[i] - Mea8000Device.BW_TABLE[j]);
	        		if (delta < maxDelta) {
	        			val = j;
	        			maxDelta = delta;
	        		}
	        	}
	
	        	frameData[0] = (byte) (frameData[0] | (byte) (val << (6-i*2)));
	        }  
    	}
        
        // Append new bytes to outputdata
		// ---------------------------------------------------------------------
        int pos = encodedData.length;
		encodedData = Arrays.copyOf(encodedData, encodedData.length+(newPitch?1:0)+frameData.length);
		if (newPitch) {
			encodedData[pos++] = pitchData;
		}
        for (int i=0; i<frameData.length; i++) {
        	encodedData[pos++] = frameData[i];
        }
		
		return encodedData;
	}

}
