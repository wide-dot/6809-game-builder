package com.widedot.toolbox.debug.ui;

import java.io.ByteArrayInputStream;
import java.io.File;
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
	private static float[] audioRefFloat;
	private static int[] audioRefInt;
	
	// synth data
	private static ArrayList<MeaFrame> meaFrames = new ArrayList<MeaFrame>();
	private static MeaFrame firstFrame = new MeaFrame();
	private static byte[] audioSynth;
	private static int[] audioSynthInt;
	
	// text input
	private static ImString input = new ImString(0x10000);
	
	// plot data
	private static int plotFrameStart = 0;
	private static int plotFrameWindow = 8;
	private static int totalframes = 0;
	private static Double[] xref = {};
	private static Integer[] yref = {};
	private static Double[] xmea = {};
	private static Integer[] ymea = {};
	
	private static final int BYTES_PER_SAMPLE = 2;
	private static final int SAMPLE_RATE = 64000;
	private static final int SAMPLE_FRAME = (SAMPLE_RATE*8)/1000; // TODO make a parameter 8, 16, 32, 64
	private static final int SAMPLE_WINDOW = SAMPLE_FRAME*4;
	
	static {
		ImPlot.createContext();
	}

	public static void show(ImBoolean showImGui) {

		if (ImGui.begin("MEA8000 Tools", showImGui)) {
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
					    totalframes = (int) Math.ceil((float)(audioRef.length/BYTES_PER_SAMPLE)/SAMPLE_FRAME);
					    if (totalframes%2 != 0) {
					    	totalframes++; // analysis requires an even number of frames
					    }
					    audioRef = Arrays.copyOf(audioRef, totalframes*SAMPLE_FRAME*BYTES_PER_SAMPLE);
					    
					    audioSynthInt = new int[totalframes*SAMPLE_FRAME];
						audioRefFloat = new float[totalframes*SAMPLE_FRAME];
						audioRefInt = new int[totalframes*SAMPLE_FRAME];
						int j = 0;
						for (int i = 0; i < audioRef.length-1; i += BYTES_PER_SAMPLE) {
							audioRefFloat[j] = (audioRef[i] << 8) | (audioRef[i+1] & 0xff);
							audioRefInt[j] = (int) audioRefFloat[j]; 
							j++;
						}
						
						// refresh plots
						plotFrameStart=0;
						refreshPlotsRef(plotFrameStart, plotFrameWindow);
						ImPlot.fitNextPlotAxes();
					}

				}

				// PLAY REF
				// -------------------------------------------------------------
				if (audioRef != null) {
					ImGui.sameLine();
					if (ImGui.button("Play ref.")) {
						playAudio(audioRef);
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
					byte[] encodedData = new byte[2]; // 2 bytes for blank header
					int formants;
					float startPitch = -1;
					
					// search forward for a starting pitch value
					for (int i=0; i<audioRef.length; i+=SAMPLE_FRAME) {
						 
						// process audio with a window
						wFrame = new WaveFrame(Arrays.copyOfRange(audioRefFloat, i, i+SAMPLE_WINDOW), wFormat);
				
						// find frame pitch
						pp.process(wFrame);
						startPitch = (float) wFrame.getFeature("Pitch");
						if (startPitch != -1) {
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
						// init starting parmaeters
						if (frame == 1) {
							firstFrame.pitch = (int) startPitch;
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
						} while (((float[]) wFrame.getFeature("Formants Frequency")).length < 4 );
						
						// map parameters to mea presets
						float[] formFreqs = (float[]) wFrame.getFeature("Formants Frequency");
						float[] formBands = (float[]) wFrame.getFeature("Formants Bandwidth");
						float pitch = (float) wFrame.getFeature("Pitch");
						
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
					
					// convert audio for playing
					int j = 0;
					audioSynth = new byte[audioSynthInt.length*2];
					for (int i=0; i<audioSynthInt.length; i++) {
						audioSynth[j++] = (byte) (audioSynthInt[i] >> 8);
						audioSynth[j++] = (byte) (audioSynthInt[i] & 0xff);
					}
					
					// add end marker of 4 null bytes
					// TODO also copy last freq, bw, ... for a perfect fade out
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
				if (audioSynth != null) {
					ImGui.sameLine();
					if (ImGui.button("Play synth.")) {
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
						refreshPlotsMea(plotFrameStart, plotFrameWindow);
					}
					ImGui.sameLine();
					
					if (ImGui.button(">")) {
						plotFrameStart++;
						if (plotFrameStart>totalframes-plotFrameWindow) {
							plotFrameStart=totalframes-plotFrameWindow;
						}
						refreshPlotsRef(plotFrameStart, plotFrameWindow);
						refreshPlotsMea(plotFrameStart, plotFrameWindow);
					}
				
					ImGui.sameLine();
					ImGui.labelText("##PlotFrames", "Frames: "+(plotFrameStart+1)+"-"+((plotFrameStart+plotFrameWindow)<totalframes?(plotFrameStart+plotFrameWindow):totalframes)+"/"+(totalframes));
				}
				
				if (ImPlot.beginPlot("Audio")) {
					ImPlot.plotLine("MEA8000", xmea, ymea);
					ImPlot.plotLine("Reference", xref, yref);
					ImPlot.endPlot();
				}
				
				// MEA FRAMES DATA
				// -------------------------------------------------------------
				ImGui.inputTextMultiline("##MEAinput", input, 1900, 400);
				
			} catch (Exception e) {
				e.printStackTrace();
			}
		}

		ImGui.end();

	}
	
	private static void setAmplFirstPass() {
		
		log.info("Find frames amplitude ...");

		int[] out;
		MeaFrame FrameA, FrameB, FrameC;
		int amplCLimit = AMPL_TABLE.length;
		
		for (int frame = 1; frame < meaFrames.size()-1; frame+=2) {
			
			log.info("Process frame: {}", frame);
			
			int bestAmplB = 0, bestAmplC = 0;
			double lowestDelta = Double.MAX_VALUE;
			
			if(frame+1 == meaFrames.size()-1) {
				amplCLimit = 1;
			} // no else here, as zeroing is made only last frame
			
			for (int amplB=0; amplB<AMPL_TABLE.length; amplB++) {				
				for (int amplC=0; amplC<amplCLimit; amplC++) {
				
					// process frame group
					// Ampl for Frame A is fixed by last frame or 0 at startup
					FrameA = new MeaFrame(meaFrames.get(frame-1));
					
					FrameB = new MeaFrame(meaFrames.get(frame));
					FrameB.i_ampl = amplB;
					FrameB.ampl = AMPL_TABLE[amplB];
					
					FrameC = new MeaFrame(meaFrames.get(frame+1));
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
			
			curFrame.i_ampl = bestAmplB;
			curFrame.ampl = AMPL_TABLE[bestAmplB];
			
			nextFrame.i_ampl = bestAmplC;
			nextFrame.ampl = AMPL_TABLE[bestAmplC];
			
			log.info("Frame: {} prevAmpl: {} curAmpl: {} nextAmpl: {}", frame, prevFrame.i_ampl, curFrame.i_ampl, nextFrame.i_ampl);
			
			out = getMeaAudioFrame(prevFrame, curFrame);
			updateSynthWave(frame, SAMPLE_FRAME, out);
			
			out = getMeaAudioFrame(curFrame, nextFrame);
			updateSynthWave(frame+1, SAMPLE_FRAME, out);

		}
		
		refreshPlotsMea(plotFrameStart, plotFrameWindow);
		ImPlot.fitNextPlotAxes();
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
			if (i < audioRef.length-1) {
				xref[j] = j*rate;
				yref[j] = (audioRef[i] << 8) | (audioRef[i+1] & 0xff);
				j++;
			}
		}
	}
	
	private static void refreshPlotsMea(int frameStart, int windowLength) {
		
		double rate = 1.0/SAMPLE_RATE;
		
		if (audioSynthInt != null) {
			xmea = new Double[windowLength*SAMPLE_FRAME];
			ymea = new Integer[windowLength*SAMPLE_FRAME];
			
			int j = 0;
			for (int i = frameStart*SAMPLE_FRAME; i < (frameStart+windowLength)*SAMPLE_FRAME; i++) {
				if (i < audioSynthInt.length) {
					xmea[j] = j*rate;
					ymea[j] = audioSynthInt[i];
					j++;
				}
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
	}
	
	public static void setMeaFilters(MeaFrame curFrame, float[] formFreqs, float[] formBands) {
		
		int delta, maxDelta;
		
		// Bandwidth
		// ---------------------------------------------------------------------
		
		// set default values if less than expected values (4 freq/band)
        for(int i = formBands.length; i < 4; i++) {
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
        for(int i = formFreqs.length; i < 3; i++) {
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
		
		// todo : la valeur de pi doit tenir compte de la taille de frame
		// << curFrame.fd
		
		if (pitch == -1) {
			curFrame.pitch = lastFrame.pitch;
			curFrame.i_pi = NOISE_INDEX;
		} else {
			curFrame.pitch = (int) pitch;
			int pi = (curFrame.pitch - lastFrame.pitch) >> curFrame.fd; 
			if (pi < -15 || pi > 15) {
				curFrame.newPitch = true;
			} else {
				curFrame.newPitch = false;
				curFrame.i_pi = (pi & 0x1f);
			}
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
		
		boolean m_noise = (curFrame.i_pi == NOISE_INDEX);
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
				if (m_noise) {
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
