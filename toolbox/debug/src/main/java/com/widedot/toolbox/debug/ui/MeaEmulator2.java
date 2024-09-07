package com.widedot.toolbox.debug.ui;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Map;
import java.util.Random;
import java.util.concurrent.CountDownLatch;

import javax.sound.sampled.AudioFormat;
import javax.sound.sampled.AudioInputStream;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.Clip;
import javax.sound.sampled.LineEvent;

import com.widedot.toolbox.debug.DataUtil;
import com.widedot.toolbox.debug.util.Mea8000Device;

import funkatronics.code.tactilewaves.dsp.FormantExtractor;
import funkatronics.code.tactilewaves.dsp.PitchProcessor;
import funkatronics.code.tactilewaves.dsp.WaveFrame;
import funkatronics.code.tactilewaves.io.WaveFormat;
import imgui.ImColor;
import imgui.ImVec2;
import imgui.ImVec4;
import imgui.extension.imguifiledialog.ImGuiFileDialog;
import imgui.extension.imguifiledialog.callback.ImGuiFileDialogPaneFun;
import imgui.extension.imguifiledialog.flag.ImGuiFileDialogFlags;
import imgui.extension.implot.ImPlot;
import imgui.flag.ImGuiCol;
import imgui.internal.ImGui;
import imgui.type.ImBoolean;
import imgui.type.ImString;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class MeaEmulator2 {

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
	private static byte[] audioRef;
	private static byte[] audioRefShifted;
	private static float[] audioRefFloat;
	private static int[] audioRefInt;
	private static int audioRefShift = 0;
	
	// synth data
	private static ArrayList<MeaFrame> meaFrames = new ArrayList<MeaFrame>();
	private static MeaFrame firstFrame = new MeaFrame();
	private static byte[] audioSynth;
	private static int[] audioSynthInt;
	
	// text input
	private static ImString intxtData = new ImString(0x10000);
	
	// parameters input
	private static int[] p_phi   = new int[1];
	private static int[] p_pitch = new int[1];
	private static int[] p_fm1   = new int[1];				
	private static int[] p_fm2   = new int[1];
	private static int[] p_fm3   = new int[1];
	private static int[] p_fm4   = new int[1];
	private static int[] p_bw1   = new int[1];				
	private static int[] p_bw2   = new int[1];
	private static int[] p_bw3   = new int[1];
	private static int[] p_bw4   = new int[1];
	private static int[] p_ampl  = new int[1];
	private static int[] p_fd    = new int[1];
	private static boolean p_noise, p_newPitch;
	
	// plot data
	private static int plotFrameStart = 0;
	private static int plotFrameCurrent = 5;
	private static int plotFrameWindow = 8;
	private static int totalframes = 0;
	private static Double[] xref = {};
	private static Integer[] yref = {};
	private static Double[] xmeaAuto = {};
	private static Integer[] ymeaAuto = {};
	
	private static final int BYTES_PER_SAMPLE = 2;
	private static final int SAMPLE_RATE = 64000;
	private static final int SAMPLE_FRAME = (SAMPLE_RATE*8)/1000; // TODO make a parameter 8, 16, 32, 64
	private static final int SAMPLE_WINDOW = SAMPLE_FRAME*2;
	
	static {
		ImPlot.createContext();
	}

	public static void show(ImBoolean showImGui) {

		if (ImGui.begin("MEA8000 Tools", showImGui)) {
			
//			ImVec2 winPos = ImGui.getWindowPos();
//			if (winPos.x<0) ImGui.setWindowPos(0, winPos.y);
//			if (winPos.y<0) ImGui.setWindowPos(winPos.x, 0);
			
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
						lastDirectory = ImGuiFileDialog.getCurrentPath()+"/";
					}
					ImGuiFileDialog.close();

					// Open the wav file specified as the first argument
					if (selection != null && !selection.isEmpty()) {
						
						inputPathName = selection.values().stream().findFirst().get();
						AudioInputStream audioISRef = AudioSystem.getAudioInputStream(new File(inputPathName));
						
						// resample to MEA8000 format
						final AudioFormat audioFormat = new AudioFormat(SAMPLE_RATE, BYTES_PER_SAMPLE * 8, 1, true, true);
					    audioISRef = AudioSystem.getAudioInputStream(audioFormat, audioISRef);
					    audioRef = audioISRef.readAllBytes();
					    audioSynthInt = new int[0];
					    shiftAudioRef();

						plotFrameStart=0;
						refreshPlotsRef(plotFrameStart, plotFrameWindow);
					}

				}

				// PLAY REF
				// -------------------------------------------------------------
				if (audioRefShifted != null) {
					ImGui.sameLine();
					if (ImGui.button("Play ref.")) {
						playAudio(audioRefShifted);
					}
				}
				
				// ENCODE
				// -------------------------------------------------------------
				ImGui.sameLine();
				if (ImGui.button("Encode")) {
					
					WaveFormat wFormat = new WaveFormat(WaveFormat.ENCODING_PCM_SIGNED, false, SAMPLE_RATE, BYTES_PER_SAMPLE*8, 1);
					WaveFrame wFrame;
					FormantExtractor fe;
					PitchProcessor pp = new PitchProcessor();
					int formants;
					float startPitch = -1;
					
					// search forward for a starting pitch value
					for (int i=0; i<audioRefShifted.length; i+=SAMPLE_FRAME) {
						 
						// process audio with a window
						wFrame = new WaveFrame(Arrays.copyOfRange(audioRefFloat, i, i+SAMPLE_WINDOW), wFormat);
				
						// find frame pitch
						pp.process(wFrame);
						startPitch = (float) wFrame.getFeature("Pitch");
						if (startPitch > 0 && startPitch < 512) {
							break;
						}
					}
					if (startPitch == -1) {
						log.info("Not Stating Pitch found.");
						startPitch = 0;
					} else {
						log.info("Starting Pitch: {}", startPitch);
					}

					// register starting parameters
					meaFrames.add(firstFrame);
					
					// process all frames for pitch, freq and bandwidth
					log.info("Find frames pitch, frequencies and bandwidths ...");
					for (int frame=1; frame<totalframes; frame++) {
						 
						log.info("Process frame: {}", frame);
						
						// process audio with a window
						wFrame = new WaveFrame(Arrays.copyOfRange(audioRefFloat, (frame-1)*SAMPLE_FRAME, (frame-1)*SAMPLE_FRAME+SAMPLE_WINDOW), wFormat);

						// first frame is a special case
						// init starting parameters
						if (frame == 1) {
							firstFrame.pitch = ((int)(startPitch + 1.0) / 2) * 2;
							firstFrame.phi = 0;
						}
						
						// find frame pitch
						pp.process(wFrame);
						
						// search frame formants
						formants=4;
						do {
							wFrame.removeFeature("Formants Frequency");
							wFrame.removeFeature("Formants Bandwidth");
							fe = new FormantExtractor(formants);
							fe.process(wFrame);
							formants++;
						} while (formants < 10 && ((float[]) wFrame.getFeature("Formants Frequency")).length < 4 );
						
						// map parameters to mea presets
						float[] formFreqs = (float[]) wFrame.getFeature("Formants Frequency");
						float[] formBands = (float[]) wFrame.getFeature("Formants Bandwidth");
						
						Float pitch = (float) wFrame.getFeature("Pitch");
						
//						log.debug("Frame: {} - Pitch: {}Hz Formant Freq: {} Formant Band: {}",
//								frame,
//								pitch,
//								formFreqs,
//								formBands);
						
						MeaFrame curFrame = new MeaFrame();
						setMeaFilters (curFrame, formFreqs, formBands);
						setMeaPitch(curFrame, pitch, meaFrames.get(frame-1));
						
//						log.debug("Frame: {} - Mapped Formant Freq: {}, Formant Band: {} - Mapped Pitch: {}, i_pi: {}, newPitch: {}",
//								frame,
//								curFrame.fm,
//								curFrame.bw,
//								curFrame.pitch,
//								curFrame.i_pi,
//								curFrame.newPitch);
						
						// first frame is a special case
						// init starting parmaeters
						if (frame == 1) {							
							for (int j=0; j<4; j++) {
								firstFrame.fm[j] = curFrame.fm[j];
								firstFrame.i_fm[j] = curFrame.i_fm[j];
								firstFrame.bw[j] = curFrame.bw[j];
								firstFrame.i_bw[j] = curFrame.i_bw[j];
							}
						}
						
						meaFrames.add(curFrame);
					}
					
					setAmplFirstPass();
					writeMeaData();		
					
					log.info("Encoding done !");
				}
				
				// DECODE
				// -------------------------------------------------------------
				ImGui.sameLine();
				if (ImGui.button("Decode")) {
//					data = HexUtils.hexStringToByteArray(input.toString());
//					meaSound = mea.compute(data);
//					// meaSound = SineWave.createSinWaveBuffer(440,3000);
//
//					int byteDepth = 2;
//					int scale = 16;
//					double rate = scale * 1.0/Mea8000Device.SAMPLERATE;
//					int length = (int) Math.ceil((double)meaSound.length / (scale * byteDepth));
//
//					xmea = new Double[length];
//					ymea = new Integer[length];
//					int j = 0;
//
//					for (int i = 0; i < meaSound.length; i += scale * byteDepth) {
//						xmea[j] = j*rate;
//						ymea[j] = (meaSound[i + 1] << 8) | (meaSound[i] & 0xff);
//						j++;
//					}
//					ImPlot.fitNextPlotAxes();
				}

				// PLAY SYNTH
				// -------------------------------------------------------------
				if (audioSynthInt != null) {
					ImGui.sameLine();
					if (ImGui.button("Play synth.")) {
						
						// convert audio for playing
						int j = 0;
						audioSynth = new byte[audioSynthInt.length*2];
						for (int i=0; i<audioSynthInt.length; i++) {
							audioSynth[j++] = (byte) (audioSynthInt[i] >> 8);
							audioSynth[j++] = (byte) (audioSynthInt[i] & 0xff);
						}
						
						playAudio(audioSynth);
					}
				}

				// PLOT
				// -------------------------------------------------------------
				if (totalframes>0) {
					if (ImGui.button("<")) {
						plotFrameStart--;
						if (plotFrameStart<0) {
							plotFrameStart=0;
						}
						refreshPlotsRef(plotFrameStart, plotFrameWindow);
						refreshPlotsMeaAuto(plotFrameStart, plotFrameWindow);
					}
					ImGui.sameLine();
					
					if (ImGui.button(">")) {
						plotFrameStart++;
						if (plotFrameStart>totalframes-plotFrameWindow) {
							plotFrameStart=totalframes-plotFrameWindow;
						}
						refreshPlotsRef(plotFrameStart, plotFrameWindow);
						refreshPlotsMeaAuto(plotFrameStart, plotFrameWindow);
					}
				
					ImGui.sameLine();
					ImGui.labelText("##PlotFrames", "Frames: "+(plotFrameStart+1)+"-"+((plotFrameStart+plotFrameWindow)<totalframes?(plotFrameStart+plotFrameWindow):totalframes)+"/"+(totalframes));
				}
				
				if (ImPlot.beginPlot("Audio")) {
					ImPlot.plotLine("Reference", xref, yref);
					ImPlot.plotLine("MEA8000 Auto", xmeaAuto, ymeaAuto);
					ImPlot.endPlot();
				}
				
				// MEA FRAMES DATA
				// -------------------------------------------------------------
				ImGui.inputTextMultiline("##MEAinput", intxtData, 120, 512);
				ImGui.sameLine();
				ImGui.dummy(80.0f, 0.0f);
				ImGui.sameLine();
				
				// map
				plotFrameCurrent = plotFrameStart+1;
				if (meaFrames.size()>plotFrameCurrent) {
				
				MeaFrame p_frame = meaFrames.get(plotFrameCurrent);	
				p_phi[0] = audioRefShift;
				p_pitch[0] = p_frame.pitch;
				p_noise = p_frame.noise;
				p_ampl[0] = p_frame.i_ampl;
				p_fm1[0] = p_frame.i_fm[0];
				p_bw1[0] = p_frame.i_bw[0];
				p_fm2[0] = p_frame.i_fm[1];
				p_bw2[0] = p_frame.i_bw[1];
				p_fm3[0] = p_frame.i_fm[2];
				p_bw3[0] = p_frame.i_bw[2];
				p_fm4[0] = p_frame.i_fm[3];
				p_bw4[0] = p_frame.i_bw[3];
				
				// TODO ajouter à l'IHM la possibilité de cocher décocher le noise
				// permettre de sélectionner le pi ou un nouveau pitch
				// permettre de parametrer le phi de départ
				
				// TODO a transformer en offset positif de la wave de référence
				ImGui.vSliderInt("##phi", 80, 512, p_phi, 0, F0, "%d");
				ImGui.sameLine();
				ImGui.dummy(80.0f, 0.0f);
				ImGui.sameLine();
				
				ImGui.vSliderInt("##pitch", 80, 512, p_pitch, 0, 510, p_pitch[0]+"Hz");
				ImGui.sameLine();
				ImGui.checkbox("noise", p_noise);
				ImGui.sameLine();
				ImGui.checkbox("new pitch", p_newPitch);
				ImGui.sameLine();
				ImGui.dummy(80.0f, 0.0f);
				ImGui.sameLine();
				
				ImGui.vSliderInt("##ampl", 80, 512, p_ampl, 0, AMPL_TABLE.length-1, (AMPL_TABLE[p_ampl[0]]/10.0)+"");
				ImGui.sameLine();
				ImGui.dummy(80.0f, 0.0f);
				ImGui.sameLine();
					           
				ImGui.vSliderInt("##fm1", 80, 512, p_fm1, 0, FM1_TABLE.length-1, FM1_TABLE[p_fm1[0]]+"Hz");
				ImGui.sameLine();
				ImGui.vSliderInt("##bw1", 40, 512, p_bw1, 0, BW_TABLE.length-1, BW_TABLE[p_bw1[0]]+"Hz");
				ImGui.sameLine();
				ImGui.vSliderInt("##fm2", 80, 512, p_fm2, 0, FM2_TABLE.length-1, FM2_TABLE[p_fm2[0]]+"Hz");
				ImGui.sameLine();
				ImGui.vSliderInt("##bw2", 40, 512, p_bw2, 0, BW_TABLE.length-1, BW_TABLE[p_bw2[0]]+"Hz");
				ImGui.sameLine();
				ImGui.vSliderInt("##fm3", 80, 512, p_fm3, 0, FM3_TABLE.length-1, FM3_TABLE[p_fm3[0]]+"Hz");
				ImGui.sameLine();
				ImGui.vSliderInt("##bw3", 40, 512, p_bw3, 0, BW_TABLE.length-1, BW_TABLE[p_bw3[0]]+"Hz");
				ImGui.sameLine();
				ImGui.vSliderInt("##fm4", 80, 512, p_fm4, FM4, FM4, FM4+"Hz");
				ImGui.sameLine();
				ImGui.vSliderInt("##bw4", 40, 512, p_bw4, 0, BW_TABLE.length-1, BW_TABLE[p_bw4[0]]+"Hz");
				ImGui.sameLine();
				ImGui.dummy(80.0f, 0.0f);
				ImGui.sameLine();
				
				ImGui.vSliderInt("##fd", 80, 512, p_fd, 0, FD_TABLE.length-1, FD_TABLE[p_fd[0]]+"ms");
				
				if (p_phi[0] != audioRefShift) {
					audioRefShift = p_phi[0];
					shiftAudioRef();
					refreshPlotsRef(plotFrameStart, plotFrameWindow);
				}
				
				p_frame.pitch = p_pitch[0];
				p_frame.noise = p_noise;
				
				setMeaPitch(p_frame, p_frame.pitch, meaFrames.get(plotFrameCurrent-1));
				
				p_frame.i_ampl = p_ampl[0];
				p_frame.ampl = AMPL_TABLE[p_ampl[0]];
				p_frame.i_fm[0] = p_fm1[0];
				p_frame.i_bw[0] = p_bw1[0];
				p_frame.i_fm[1] = p_fm2[0];
				p_frame.i_bw[1] = p_bw2[0];
				p_frame.i_fm[2] = p_fm3[0];
				p_frame.i_bw[2] = p_bw3[0];
				p_frame.i_fm[3] = p_fm4[0];
				p_frame.i_bw[3] = p_bw4[0];
				p_frame.fm[0] = FM1_TABLE[p_frame.i_fm[0]];
				p_frame.bw[0] = BW_TABLE[p_frame.i_bw[0]];
				p_frame.fm[1] = FM2_TABLE[p_frame.i_fm[1]];
				p_frame.bw[1] = BW_TABLE[p_frame.i_bw[1]];
				p_frame.fm[2] = FM3_TABLE[p_frame.i_fm[2]];
				p_frame.bw[2] = BW_TABLE[p_frame.i_bw[2]];
				p_frame.fm[3] = FM4;
				p_frame.bw[3] = BW_TABLE[p_frame.i_bw[3]];

				int[] out = getMeaAudioFrame(meaFrames.get(plotFrameCurrent-1), p_frame);
				updateSynthWave(plotFrameCurrent, SAMPLE_FRAME, out);
				refreshPlotsMeaAuto(plotFrameStart, plotFrameWindow);
				
				out = getMeaAudioFrame(p_frame, meaFrames.get(plotFrameCurrent+1));
				updateSynthWave(plotFrameCurrent+1, SAMPLE_FRAME, out);
				refreshPlotsMeaAuto(plotFrameStart, plotFrameWindow);
				}
				
			} catch (Exception e) {
				e.printStackTrace();
			}
		}

		ImGui.end();

	}
	
	private static void shiftAudioRef() {
		
		int offset = audioRefShift * 2;
		
	    totalframes = (int) Math.ceil((float)((audioRef.length+offset)/BYTES_PER_SAMPLE)/SAMPLE_FRAME);
	    if (totalframes%2 != 0) {
	    	totalframes++; // analysis requires an even number of frames
	    }
	    audioRefShifted = new byte[totalframes*SAMPLE_FRAME*BYTES_PER_SAMPLE]; 
	    for (int i=0; i<audioRef.length; i++) {
	    	audioRefShifted[offset+i] = audioRef[i];
	    }
	    
	    audioSynthInt = Arrays.copyOf(audioSynthInt, totalframes*SAMPLE_FRAME);
		audioRefFloat = new float[totalframes*SAMPLE_FRAME];
		audioRefInt = new int[totalframes*SAMPLE_FRAME];
		int j = 0;
		for (int i = 0; i < audioRefShifted.length-1; i += BYTES_PER_SAMPLE) {
			audioRefFloat[j] = (audioRefShifted[i] << 8) | (audioRefShifted[i+1] & 0xff);
			audioRefInt[j] = (int) audioRefFloat[j]; 
			j++;
		}
	}

	private static byte[] writeMeaData() {
		
		byte[] encodedData = new byte[0xFFFFFF];
		int pos = 2;
		
		// set header pitch
		encodedData[pos++] = (byte) ((meaFrames.get(0).pitch/2) & 0xff);
		intxtData.set("Pitch: " + DataUtil.byteToHex(encodedData[pos-1]) + "\r\n");
		
		for (int frame=1; frame<meaFrames.size(); frame++) {
			
        	// set bandwidths
	        for(int i = 0; i < 4; i++) {
	        	encodedData[pos] = (byte) (encodedData[pos] | (byte) (meaFrames.get(frame).i_bw[i] << (6-i*2)));
	        }
	        
	        // set frequencies
    		encodedData[pos+2] = (byte) (encodedData[pos+2] | (byte) ((meaFrames.get(frame).i_fm[0] & 0b11111) << 3));
    		encodedData[pos+1] = (byte) (encodedData[pos+1] | (byte) (meaFrames.get(frame).i_fm[1] & 0b11111));
    		encodedData[pos+1] = (byte) (encodedData[pos+1] | (byte) ((meaFrames.get(frame).i_fm[2] & 0b111) << 5));
	    	
	    	// set amplitude
	    	encodedData[pos+2] = (byte) (encodedData[pos+2] | (byte) ((meaFrames.get(frame).i_ampl >> 1) & 0b111));
	    	encodedData[pos+3] = (byte) (encodedData[pos+3] | (byte) ((meaFrames.get(frame).i_ampl & 0b1) << 7));
			
	    	// set pitch increment
	    	encodedData[pos+3] = (byte) (encodedData[pos+3] | (byte) (meaFrames.get(frame).i_pi & 0b11111));
	    	
    		intxtData.set(intxtData.get() + frame + ": " + DataUtil.bytesToHex(encodedData, pos, 4) + "\r\n");
	    	
	    	pos += 4;
	    	
	    	if (meaFrames.get(frame).i_ampl == 0 && frame+1<meaFrames.size()) {
	    		encodedData[pos++] = (byte) ((meaFrames.get(frame+1).pitch/2) & 0xff);
	    		intxtData.set(intxtData.get() + "\r\nPitch: " + DataUtil.byteToHex(encodedData[pos-1]) + "\r\n");
	    	}
		}
		
		// update header with total length
		encodedData[0] = (byte) ((pos & 0xff00) >> 8);
		encodedData[1] = (byte) (pos & 0xff);
		intxtData.set("Length: " + DataUtil.bytesToHex(encodedData, 0, 2) + "\r\n\r\n" + intxtData.get() + "\r\n");	
		
		byte[] finalData = Arrays.copyOf(encodedData, pos);	
		
		try {
			Files.write(Path.of(inputPathName+".mea"), finalData);
		} catch (IOException e) {
			e.printStackTrace();
		}
		
		return finalData;        
	}
	
	private static void setAmplFirstPass() {
		
		log.info("Find frames amplitude ...");

		int[] out;
		MeaFrame FrameA, FrameB, FrameC;
		int amplBLimit, amplCLimit;
		
		for (int frame = 1; frame < meaFrames.size()-1; frame+=2) {
			
			log.info("Process frame: {}", frame);
			
			int bestAmplB = 0, bestAmplC = 0;
			double lowestDelta = Double.MAX_VALUE;
			
			// in case of new Pitch, previous frame is faded to 0
			if(meaFrames.get(frame+1).newPitch) {
				amplBLimit = 1;
			} else {
				amplBLimit = AMPL_TABLE.length;
			}
			
			// in case of new Pitch, previous frame is faded to 0
			// last frame is also faded to 0
			if((frame+2 < meaFrames.size() && meaFrames.get(frame+2).newPitch) || frame+1 == meaFrames.size()-1) {
				amplCLimit = 1;
			} else {
				amplCLimit = AMPL_TABLE.length;
			}
			
			for (int amplB=0; amplB<amplBLimit; amplB++) {				
				for (int amplC=0; amplC<amplCLimit; amplC++) {
				
					// process frame group
					// Ampl for Frame A is fixed by last frame or 0 at startup
					FrameA = new MeaFrame(meaFrames.get(frame-1));
					
					FrameB = new MeaFrame(meaFrames.get(frame));
					if(meaFrames.get(frame+1).newPitch) {
						FrameB.copyFilters(meaFrames.get(frame+1));
					}
					FrameB.i_ampl = amplB;
					FrameB.ampl = AMPL_TABLE[amplB];
					
					FrameC = new MeaFrame(meaFrames.get(frame+1));
					if(frame+2 < meaFrames.size() && meaFrames.get(frame+2).newPitch) {
						FrameC.copyFilters(meaFrames.get(frame+2));
					}
					FrameC.i_ampl = amplC;
					FrameC.ampl = AMPL_TABLE[amplC];
									
					out = getMeaAudioFrame(FrameA, FrameB);
					double deltaAB = getWaveDelta(audioRefInt, (frame-1)*SAMPLE_FRAME, SAMPLE_FRAME, out);
					out = getMeaAudioFrame(FrameB, FrameC);
					double deltaBC = getWaveDelta(audioRefInt, frame*SAMPLE_FRAME, SAMPLE_FRAME, out);
					
					if (deltaAB+deltaBC < lowestDelta) {
						lowestDelta = deltaAB+deltaBC;
						bestAmplB = amplB;
						bestAmplC = amplC;
						log.info("Frame: {} AmplB: {} DeltaAB: {} AmplC: {} DeltaBC: {}", frame, amplB, deltaAB, amplC, deltaBC);
					}
				}
			}
	
			MeaFrame prevFrame = meaFrames.get(frame-1);
			MeaFrame curFrame = meaFrames.get(frame);
			MeaFrame nextFrame = meaFrames.get(frame+1);
			
			if(meaFrames.get(frame+1).newPitch) {
				curFrame.copyFilters(meaFrames.get(frame+1));
			}
			curFrame.i_ampl = bestAmplB;
			curFrame.ampl = AMPL_TABLE[bestAmplB];
			
			if(frame+2 < meaFrames.size() && meaFrames.get(frame+2).newPitch) {
				nextFrame.copyFilters(meaFrames.get(frame+2));
			}
			nextFrame.i_ampl = bestAmplC;
			nextFrame.ampl = AMPL_TABLE[bestAmplC];
			
			log.info("Frame: {} prevAmpl: {} curAmpl: {} nextAmpl: {}", frame, prevFrame.i_ampl, curFrame.i_ampl, nextFrame.i_ampl);
			
			out = getMeaAudioFrame(prevFrame, curFrame);
			updateSynthWave(frame, SAMPLE_FRAME, out);
			
			out = getMeaAudioFrame(curFrame, nextFrame);
			updateSynthWave(frame+1, SAMPLE_FRAME, out);

		}
		
		refreshPlotsMeaAuto(plotFrameStart, plotFrameWindow);
	}
	
	private static void updateSynthWave(int frame, int frameLength, int[] data) {
		// update sample audio frame in global wave Synth
		// frame parameter start at 1
		
		int j = (frame-1)*frameLength;
		for (int k = 0; k < data.length; k++) {
			audioSynthInt[j++] = data[k];
		}
	}
	
	private static double getWaveDelta(int[] ref, int start, int length, int[] frame) {
		long delta = 0;
		long rmsRef = 0;
		long rmsFrame = 0;
		
		for (int i = start; i < start+length; i++) {
			rmsRef += ref[i]*ref[i];
		}
		rmsRef = (long) Math.sqrt(rmsRef/length);
		
		for (int i = 0; i < frame.length; i++) {
			rmsFrame += frame[i]*frame[i];
		}
		rmsFrame = (long) Math.sqrt(rmsFrame/frame.length);
		
		delta = Math.abs(rmsFrame - rmsRef);
		
		return delta;
	}
	
	private static void playAudio(byte[] audio) {
		AudioInputStream audioIS = new AudioInputStream(
		        new ByteArrayInputStream(audio), 
		        new AudioFormat(SAMPLE_RATE, BYTES_PER_SAMPLE*8, 1, true, true),
		        audio.length/2);
		
        CountDownLatch syncLatch = new CountDownLatch(1);
		try {
			Clip clip = AudioSystem.getClip();
			// Listener which allow method return once sound is completed
			clip.addLineListener(e -> {
				if (e.getType() == LineEvent.Type.STOP) {
					syncLatch.countDown();
				}
			});
			clip.open(audioIS);
			clip.start();
			syncLatch.await();
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
	
	private static void refreshPlotsRef(int frameStart, int windowLength) {
		
		double rate = 1.0/SAMPLE_RATE;
		
		xref = new Double[windowLength*SAMPLE_FRAME];
		yref = new Integer[windowLength*SAMPLE_FRAME];
		
		int j = 0;
		for (int i = frameStart*SAMPLE_FRAME*BYTES_PER_SAMPLE; i < (frameStart+windowLength)*SAMPLE_FRAME*BYTES_PER_SAMPLE; i += BYTES_PER_SAMPLE) {
				xref[j] = j*rate;
				if (i < audioRefShifted.length-1) {
					yref[j] = (audioRefShifted[i] << 8) | (audioRefShifted[i+1] & 0xff);
				} else {
					yref[j] = 0;
				}
				j++;
		}
		
		ImPlot.fitNextPlotAxes();
	}
	
	private static void refreshPlotsMeaAuto(int frameStart, int windowLength) {
		
		double rate = 1.0/SAMPLE_RATE;
		
		if (audioSynthInt != null) {
			xmeaAuto = new Double[windowLength*SAMPLE_FRAME];
			ymeaAuto = new Integer[windowLength*SAMPLE_FRAME];
			
			int j = 0;
			for (int i = frameStart*SAMPLE_FRAME; i < (frameStart+windowLength)*SAMPLE_FRAME; i++) {
				xmeaAuto[j] = j*rate;
				if (i < audioSynthInt.length) {
					ymeaAuto[j] = audioSynthInt[i];
				} else {
					ymeaAuto[j] = 0;
				}
				j++;
			}
		}
		
		ImPlot.fitNextPlotAxes();
	}
			
	private static final int QUANT = 512; // samples for 8ms at 64kHz
	private static final int TABLE_LEN = 3600;
	private static final int NOISE_LEN = 8192;
	private static final int F0 = (3840000 / 480); // digital filters work at 8 kHz
	private static final int SUPERSAMPLING = 8; // filtered output is supersampled x 8
	
	private static final int[]   FM1_TABLE   = { 150, 162, 174, 188, 202, 217, 233, 250, 267, 286, 305, 325, 346, 368, 391, 415, 440, 466, 494, 523, 554, 587, 622, 659, 698, 740, 784, 830, 880, 932, 988, 1047 };
	private static final int[]   FM2_TABLE   = { 440, 466, 494, 523, 554, 587, 622, 659, 698, 740, 784, 830, 880, 932, 988, 1047, 1100, 1179, 1254, 1337, 1428, 1528, 1639, 1761, 1897, 2047, 2214, 2400, 2609, 2842, 3105, 3400 };
	private static final int[]   FM3_TABLE   = { 1179, 1337, 1528, 1761, 2047, 2400, 2842, 3400 };
	private static final int[][] FM_TABLES   = {FM1_TABLE, FM2_TABLE, FM3_TABLE};
	private static final int     FM4         = 3500;
	private static final int[]   BW_TABLE    = { 726, 309, 125, 50 };
	private static final int[]   AMPL_TABLE  = { 0, 8, 11, 16, 22, 31, 44, 62, 88, 125, 177, 250, 354, 500, 707, 1000 };
	private static final int[]   PI_TABLE    = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0, -15, -14, -13, -12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1 };
	private static final int     NOISE_INDEX = 16;
	private static final int[]   FD_TABLE    = {8, 16, 32, 64};
    private static final int[]   m_audio     = new int[QUANT];
	
	private static double[] m_cos_table = new double[TABLE_LEN];
	private static double[] m_exp_table = new double[TABLE_LEN];
	private static double[] m_exp2_table = new double[TABLE_LEN];
	private static int[] m_noise_table = new int[NOISE_LEN];
	private static Random random = new Random();
	
	static {
		for (int i = 0; i < TABLE_LEN; i++) {
			double f = (double) i / F0;
			m_cos_table[i] = 2.0 * Math.cos(2.0 * Math.PI * f) * QUANT;
			m_exp_table[i] = Math.exp(-Math.PI * f) * QUANT;
			m_exp2_table[i] = Math.exp(-2.0 * Math.PI * f) * QUANT;
		}
		
		for (int i = 0; i < m_noise_table.length; i++) {
			m_noise_table[i] = (random.nextInt(2 * (int) QUANT)) - (int) QUANT;
		}
	}
	
	private static class MeaFrame {
		int     fd; // 0=8ms, 1=16ms, 2=32ms, 3=64ms
		int     phi;
		int     pitch;
		int[]   output;
		int[]   last_output;
		int     sample;
		boolean newPitch;
		boolean noise;
		
		int     ampl;
		int[]   fm;
		int[]   bw;

		int     i_pi;
		int     i_ampl;
		int[]   i_fm;
		int[]   i_bw;
		
		MeaFrame () {
			output = new int[4];
			last_output = new int[4];
			fm = new int[4];
			bw = new int[4];
			i_fm = new int[4];
			i_bw = new int[4];
		}
		
		MeaFrame(MeaFrame src) {
			this.fd = src.fd;
			this.phi = src.phi;
			this.pitch = src.pitch;
			this.output = Arrays.copyOf(src.output, src.output.length);
			this.last_output = Arrays.copyOf(src.last_output, src.last_output.length);
			this.sample = src.sample;
			this.newPitch = src.newPitch;
			
			this.ampl = src.ampl;
			this.fm = Arrays.copyOf(src.fm, src.fm.length);
			this.bw = Arrays.copyOf(src.bw, src.bw.length);
			
			this.i_pi = src.i_pi;
			this.i_ampl = src.i_ampl;
			this.i_fm = Arrays.copyOf(src.i_fm, src.i_fm.length);
			this.i_bw = Arrays.copyOf(src.i_bw, src.i_bw.length);
			
		}
		
		public void copyFilters(MeaFrame src) {
			this.fm = Arrays.copyOf(src.fm, src.fm.length);
			this.bw = Arrays.copyOf(src.bw, src.bw.length);
			this.i_fm = Arrays.copyOf(src.i_fm, src.i_fm.length);
			this.i_bw = Arrays.copyOf(src.i_bw, src.i_bw.length);
		}
	}
	
	public static void setMeaFilters(MeaFrame curFrame, float[] formFreqs, float[] formBands) {
		
		int delta, maxDelta;
		
		// Bandwidth
		// ---------------------------------------------------------------------
		
		// set default values if less than expected values (4 freq/band)
		int start = formBands.length;
		formBands = Arrays.copyOf(formBands, 4);
        for(int i = start; i < 4; i++) {
        	formBands[i] = BW_TABLE[0];
        }
        
        // match preset values, and set indexes
        for(int i = 0; i < 4; i++) {
            maxDelta = Integer.MAX_VALUE;
        	for (int j = 0; j < BW_TABLE.length; j++) {
        		delta = Math.abs((int) formBands[i] - BW_TABLE[j]);
        		if (delta < maxDelta) {
        			maxDelta = delta;
        			curFrame.i_bw[i] = j;
        			curFrame.bw[i] = BW_TABLE[j];
        		} else {
        			break;
        		}
        	}
        	// PERFECT MODE
        	// curFrame.bw[i] = (int) formBands[i];
        	// ------------
        } 
		
		// Frequency
		// ---------------------------------------------------------------------
		
		// set default values if less than expected values
		start = formFreqs.length;
		formFreqs = Arrays.copyOf(formFreqs, 3);
        for(int i = start; i < 3; i++) {
        	formFreqs[i] = FM_TABLES[i][0];
        }
        
        // match preset values, and set indexes
        for(int i = 0; i < 3; i++) {
            maxDelta = Integer.MAX_VALUE;
        	for (int j = 0; j < FM_TABLES[i].length; j++) {
        		delta = Math.abs((int) formFreqs[i] - FM_TABLES[i][j]);
        		if (delta < maxDelta) {
        			maxDelta = delta;
        			curFrame.i_fm[i] = j;
        			curFrame.fm[i] = FM_TABLES[i][j];
        		} else {
        			break;
        		}
        	}
        	// PERFECT MODE
        	//curFrame.fm[i] = (int) formFreqs[i];    
        	// ------------
        }
        curFrame.i_fm[3] = 0;	
        curFrame.fm[3] = FM4;	
	}
	
	public static void setMeaPitch(MeaFrame curFrame, float pitch, MeaFrame lastFrame) {
				
		if (curFrame.noise || pitch == -1) {
			curFrame.pitch = lastFrame.pitch;
			curFrame.noise = true;
			curFrame.i_pi = NOISE_INDEX;
		} else {
			curFrame.pitch = (int) pitch;
			int pi = (curFrame.pitch - lastFrame.pitch) >> curFrame.fd; 
			if (pi < -15 || pi > 15) {
				curFrame.newPitch = true;
				curFrame.pitch = (curFrame.pitch / 2) * 2; // round by two the starting pitch
				curFrame.i_pi = 0;
			} else {
				curFrame.newPitch = false;
				curFrame.i_pi = (pi & 0x1f);
			}
			curFrame.noise = false;
		}
	}
	
	public static int[] getMeaAudioFrame(MeaFrame lastFrame, MeaFrame curFrame) {

		int m_framelog = curFrame.fd + 9; // 64 samples / ms
		int m_framelength = 1 << m_framelog;
		int m_framepos = 0;
		int m_audiopos = 0;
		int m_lastsample = 0;
		int m_samplingPos = 0;
		int fm, bw, b, c;
		
		//log.info("ENTREE {} {} {} {}", lastFrame.last_output, lastFrame.output, curFrame.last_output, curFrame.output);
		//log.info("ENTREE {} {} {} {}", lastFrame.fm, lastFrame.bw, curFrame.fm, curFrame.bw);
		
		if (curFrame.noise) { 
			curFrame.i_pi = NOISE_INDEX;
		}
		curFrame.phi = lastFrame.phi;
		curFrame.sample = lastFrame.sample;
		for (int i=0; i<4; i++) {
			curFrame.output[i] = lastFrame.output[i];
			curFrame.last_output[i] = lastFrame.last_output[i];
		}
		
		while(m_framepos < m_framelength) {
			m_samplingPos = m_framepos % SUPERSAMPLING;
			if (m_samplingPos == 0) {
				m_lastsample = curFrame.sample;
				
				// audio source
				// -------------------------------------------------------------
				if (curFrame.noise) {
					// noise gen
					curFrame.phi = (curFrame.phi + 1) % NOISE_LEN;
					curFrame.sample = m_noise_table[curFrame.phi];
				} else {
					// freq gen
					int pitch = lastFrame.pitch + (((curFrame.pitch - lastFrame.pitch) * m_framepos) >> m_framelog);
					curFrame.phi = (curFrame.phi + pitch) % F0;
					curFrame.sample = ((curFrame.phi % F0) * QUANT * 2) / F0 - QUANT;
				}

				// amplitude
				// -------------------------------------------------------------
				curFrame.sample = (curFrame.sample * (lastFrame.ampl + (((curFrame.ampl - lastFrame.ampl) * m_framepos) >> m_framelog)))/32;
				
				// filter
				// -------------------------------------------------------------
				for (int i = 0; i < 4; i++) {
					fm = lastFrame.fm[i] + (((curFrame.fm[i] - lastFrame.fm[i]) * m_framepos) >> m_framelog);
					bw = lastFrame.bw[i] + (((curFrame.bw[i] - lastFrame.bw[i]) * m_framepos) >> m_framelog);
					
					b = (int) (m_cos_table[fm] * m_exp_table[bw] / QUANT);
					c = (int) m_exp2_table[bw];

					curFrame.sample = curFrame.sample + (b * curFrame.output[i] - c * curFrame.last_output[i]) / QUANT;

					curFrame.last_output[i] = curFrame.output[i];
					curFrame.output[i] = curFrame.sample;
				}
				
				if (curFrame.sample >  32767) curFrame.sample =  32767;
				if (curFrame.sample < -32768) curFrame.sample = -32768;
				
				m_audio[m_audiopos++] = m_lastsample;
			} else {
				m_audio[m_audiopos++] = m_lastsample + ((m_samplingPos * (curFrame.sample - m_lastsample)) / SUPERSAMPLING);
			}
			m_framepos++;
		}
			
		//log.info("SORTIE {} {} {} {}", lastFrame.last_output, lastFrame.output, curFrame.last_output, curFrame.output);

		
		return m_audio;
	}

}
