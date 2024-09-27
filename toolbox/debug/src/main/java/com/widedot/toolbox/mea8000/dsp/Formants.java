package com.widedot.toolbox.mea8000.dsp;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;

import com.widedot.toolbox.mea8000.Mea8000Decoder;

import funkatronics.code.tactilewaves.dsp.toolbox.Filter;
import funkatronics.code.tactilewaves.dsp.toolbox.LPC;
import funkatronics.code.tactilewaves.dsp.toolbox.Window;
import funkatronics.code.tactilewaves.dsp.toolbox.YIN;
import imgui.extension.implot.ImPlot;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Formants {

	public static final int SAMPLE_SIZE_IN_BYTES = 2;
	public static final int SAMPLE_SIZE_IN_BITS = SAMPLE_SIZE_IN_BYTES*8;
	public static final int SAMPLE_RATE = 64000;
	public static final int CHANNELS = 1;
	public static final boolean BIG_ENDIAN = true;
	
	private static final int SAMPLE_1MS = SAMPLE_RATE/1000;
	private static final int SAMPLE_FRAME = SAMPLE_1MS*8;         // frame highest resolution
	private static final int SAMPLE_WINDOW_FREQ = SAMPLE_1MS*64;  // window for formant analysis
	private static final int SAMPLE_WINDOW_PITCH = SAMPLE_1MS*32; // window for pitch analysis
	
	// formant search
	public static List<List<double[]>> formants = new ArrayList<>(); // for each frame, gives all formants
	public static List<Float> pitches = new ArrayList<>();           // for each frame, gives all formants
	
	// formant tracks
	public static List<FormantTrack> curTracks = new ArrayList<>(); // current formant tracks being computed
	public static List<FormantTrack> cmpTracks = new ArrayList<>(); // completed formant tracks
	public static List<List<FormantTrack>> synthTracks = new ArrayList<List<FormantTrack>>(4); // for each synth, gives all formants tracks

	public static class FormantTrack {
		Map<Integer, double[]> f;
		
		public FormantTrack() {
			f = new HashMap<>();
		}
	}
	
	// formant plots
	public static double[][] xf;
	public static double[][] yf;
	public static int[] fl;
	
	private Formants() {};
	
	public static void compute(float[] audioIn) {
		
		formants.clear();
		pitches.clear();
		
		// process all frames for pitch, freq and bandwidth
		for (int s=0; s<audioIn.length; s+=SAMPLE_FRAME) {
			
			// find frame pitch
			pitches.add(YIN.estimatePitch(Arrays.copyOfRange(audioIn, s, s+SAMPLE_WINDOW_PITCH), SAMPLE_RATE));
			
			// window
			float[] x = Window.hamming(Arrays.copyOfRange(audioIn, s, s+SAMPLE_WINDOW_FREQ));
			
			// pre-Emphasis filtering
			x = Filter.preEmphasis(x);
			
	    	// get list of formant (frequency, bandwidth) pairs
	        double[][] f = LPC.estimateFormants(x, 26, SAMPLE_RATE);

	        List<double[]> ft = new ArrayList<>();
	        double[] el;
	        for(int i = 0; i < f.length; i++) {
	        	
	        	// keep valid formants
	        	if(f[i][0] > 140.0 && f[i][0] < 4000.0 && f[i][1] < 800.0) {
	        		
        			el = new double[2];
        			el[0] = f[i][0];
        			el[1] = f[i][1];
        			ft.add(el);
	        	}
	        }
	        
	        formants.add(ft);
		}
		
		computePlots(formants);
	}
	
	public static void computeTracks() {
		
		for(List<double[]> entry : formants) {
			for (double[] f : entry) {
				
			}
		}
		// curTracks
	}
	
	public static void computePlots(List<List<double[]>> formants) {
		
		// compute length for array allocation
		fl = new int[4];
		for (int i=0; i<4; i++) {
			fl[i]=0;
		}
		
		for(List<double[]> entry : formants) {
			for (double[] f : entry) {
				if (f[1] < (Mea8000Decoder.BW_TABLE[3]+Mea8000Decoder.BW_TABLE[2])/2) {
					fl[0]++;
				} else if (f[1] < (Mea8000Decoder.BW_TABLE[2]+Mea8000Decoder.BW_TABLE[1])/2) {
					fl[1]++;
				} else if (f[1] < (Mea8000Decoder.BW_TABLE[1]+Mea8000Decoder.BW_TABLE[0])/2) {
					fl[2]++;
				} else {
					fl[3]++;
				}
			}
		}

		xf = new double[fl.length][];
		yf = new double[fl.length][];		
		
		for (int i=0; i<fl.length; i++) {
			xf[i] = new double[fl[i]];
			yf[i] = new double[fl[i]];
		}

		int[] i = new int[fl.length];
		double frame = 0;
		for(List<double[]> entry : formants) {
			for (double[] f : entry) {
				if (f[1] < (Mea8000Decoder.BW_TABLE[3]+Mea8000Decoder.BW_TABLE[2])/2) {
					xf[0][i[0]] = frame;
					yf[0][i[0]++] = f[0];
				} else if (f[1] < (Mea8000Decoder.BW_TABLE[2]+Mea8000Decoder.BW_TABLE[1])/2) {
					xf[1][i[1]] = frame;
					yf[1][i[1]++] = f[0];
				} else if (f[1] < (Mea8000Decoder.BW_TABLE[1]+Mea8000Decoder.BW_TABLE[0])/2) {
					xf[2][i[2]] = frame;
					yf[2][i[2]++] = f[0];
				} else {
					xf[3][i[3]] = frame;
					yf[3][i[3]++] = f[0];
				}
			}
			frame++;
		}
		
		ImPlot.setNextAxesToFit();
	}
}
