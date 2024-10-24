package com.widedot.toolbox.mea8000.dsp;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.apache.commons.math3.analysis.polynomials.PolynomialSplineFunction;

import com.widedot.toolbox.mea8000.Mea8000Decoder;

import funkatronics.code.tactilewaves.dsp.toolbox.Filter;
import funkatronics.code.tactilewaves.dsp.toolbox.LPC;
import funkatronics.code.tactilewaves.dsp.toolbox.Window;
import funkatronics.code.tactilewaves.dsp.toolbox.YIN;
import imgui.extension.implot.ImPlot;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Formants {

	private static final int SAMPLE_SIZE_IN_BYTES = 2;
	private static final int SAMPLE_SIZE_IN_BITS = SAMPLE_SIZE_IN_BYTES*8;
	private static final int SAMPLE_RATE = 64000;
	private static final int CHANNELS = 1;
	private static final boolean BIG_ENDIAN = true;
	
	private static final int SAMPLE_1MS = SAMPLE_RATE/1000;
	private static final int SAMPLE_FRAME = SAMPLE_1MS*8;         // frame highest resolution
	private static final int SAMPLE_WINDOW_FREQ = SAMPLE_1MS*64;  // window for formant analysis
	private static final int SAMPLE_WINDOW_PITCH = SAMPLE_1MS*32; // window for pitch analysis
	
	// synth properties
	// formant tracks are splitted into freq ranges to accomodate the 4 synth generators and common ranges
	// FM1
	// (>=0) 150, 162, 174, 188, 202, 217, 233, 250, 267, 286, 305, 325, 346, 368, 391, 415, (<427.5)
	// (>=427.5), 440, 466, 494, 523, 554, 587, 622, 659, 698, 740, 784, 830, 880, 932, 988, 1047, (<1073.5)
	//
	// FM 2
	// (>=427.5), 440, 466, 494, 523, 554, 587, 622, 659, 698, 740, 784, 830, 880, 932, 988, 1047, (<1073.5)
	// (>=1073.5), 1100, (<1139.5)
	// (>=1139.5), 1179, 1254, 1337, 1428, 1528, 1639, 1761, 1897, 2047, 2214, 2400, 2609, 2842, 3105, 3400, (<3450)
	//
	// FM3
	// (>=1139.5), 1179, 1337, 1528, 1761, 2047, 2400, 2842, 3400, (<3450)
	//
	// FM4
	// (>=3450), 3500, (<=4000)
	
	private static double[] freqRange = new double[] {427.5, 1073.5, 1139.5, 3450, Double.MAX_VALUE}; // FM1, FM1+FM2, FM2, FM2+FM3, FM4
	private static boolean[][] synthRange = new boolean[][] {
		new boolean[]{true,  false, false, false}, 
		new boolean[]{true,  true,  false, false}, 
		new boolean[]{false, true,  false, false}, 
		new boolean[]{false, true,  true,  false}, 
		new boolean[]{false, false, false, true}};
	
	// formant analysis
	private static List<List<double[]>> formants = new ArrayList<>(); // for each frame, gives all formants
	private static List<Float> pitches = new ArrayList<>();           // for each frame, gives all pitches
	private static SynthTrack[] tracks = new SynthTrack[4];
	
	// plots for rendering on graph
	public static double[][] xf;
	public static double[][] yf;
	
	public static class SynthTrack {
		public List<List<double[]>> formants;
		public double[] x;
		public double[] f;
		public double[] b;
		public PolynomialSplineFunction s;
		
		public SynthTrack() {
			formants = new ArrayList<>();
		}
	
		public void compute() {
			
			// init data structure
			int nbFormants = 0;
			for (List<double[]> formantFrame : formants) {
				nbFormants += formantFrame.size();
			}
			x = new double[nbFormants];
			f = new double[nbFormants];
			b = new double[nbFormants];
			
			// copy formant values
			int i=0, frame=0;
			for (List<double[]> formantFrame : formants) {
				for (double[] formantValue : formantFrame) {
					x[i] = frame;
					f[i] = formantValue[0];
					b[i] = formantValue[1];
					i++;
				}
				frame++;
			}
		}
	}
	
	public static void compute(float[] audioIn) {
	
		formants.clear();
		pitches.clear();
		
        for (int synth=0; synth<4; synth++) {
        	tracks[synth] = new SynthTrack();
        }
		
		// process all frames for pitch, freq and bandwidth
		for (int s=0; s<audioIn.length; s+=SAMPLE_FRAME) {
			
			// find frame pitch
			pitches.add(YIN.estimatePitch(Arrays.copyOfRange(audioIn, s, s+SAMPLE_WINDOW_PITCH), SAMPLE_RATE));
			
			// window
			float[] x = Window.hamming(Arrays.copyOfRange(audioIn, s, s+SAMPLE_WINDOW_FREQ));
			
			// pre-Emphasis filtering
			x = Filter.preEmphasis(x);
		
	        List<double[]> formantsByFrame = new ArrayList<double[]>();
	        List<List<double[]>> formantsBySynth = new ArrayList<List<double[]>>();
	        for (int synth=0; synth<4; synth++) {
	        	formantsBySynth.add(new ArrayList<double[]>());
	        }
	        double[] el;
	        
			for (int nodes=20; nodes<=40; nodes++) {
		    	// get list of formant (frequency, bandwidth) pairs
		        double[][] f = LPC.estimateFormants(x, nodes, SAMPLE_RATE);
		
		        for(int i = 0; i < f.length; i++) {
		        	
		        	// filter valid formants
		        	if(f[i][0] > 140.0 && f[i][0] < 4000.0 && f[i][1] < 800.0) {
		        		
		    			el = new double[2];
		    			el[0] = f[i][0];
		    			el[1] = f[i][1];
		    			formantsByFrame.add(el);
		    			
		    			boolean[] isInRange = getSynthRange(f[i][0]);
		    			for (int synth=0; synth<4; synth++) {
		    				if (isInRange[synth]) {
		    					formantsBySynth.get(synth).add(el);
		    				}
		    			}
		        	}
		        }
			}
			
	        formants.add(formantsByFrame);
	        for (int synth=0; synth<4; synth++) {
	        	tracks[synth].formants.add(formantsBySynth.get(synth));
	        }
		}
		
        for (int synth=0; synth<4; synth++) {
        	tracks[synth].compute();
        }
        
		computePlots();
	}
		
	private static boolean[] getSynthRange(double f) {
		int i = 0;
		while (i < freqRange.length && f >= freqRange[i]) {
			i++;
		}
		return synthRange[i];
	}
	
	public static void computePlots() {
		
		// compute length for array allocation
		// formant plots
		int[] fl = new int[4];
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
	
//	public static class FormantTrack {
//		Map<Integer, double[]> f; // [0]: fm, [1]: bw
//		int firstFrame;
//		int lastFrame;
//		int trackSize;
//		Double minF;
//		Double maxF;
//		boolean[] usedSynths;
//		int synth;
//		
//		public FormantTrack() {
//			f = new HashMap<>();
//			firstFrame = 0;
//			lastFrame = 0;
//			trackSize = 0;
//			minF = Double.MAX_VALUE;
//			maxF = Double.MIN_VALUE;
//			usedSynths = new boolean[]{true, true, true, true};
//			synth = -1;
//		}
//	}
//
//public static void computeTracks() {
//	
//	int framesGap = 5;
//	int frame = 0;
//	
//	for(List<double[]> entry : formants) {
//		for (double[] f : entry) {
//
//			// only process formants with narrow bw
//			if (f[1] < (Mea8000Decoder.BW_TABLE[2]+Mea8000Decoder.BW_TABLE[1])/2) {
//				
//				// try to add formants to existing tracks
//				int i = 0;
//				int bestIndex = -1;
//				double bestDistance = Double.MAX_VALUE;
//				for (FormantTrack ct : currentTracks) {
//					if (ct.lastFrame < frame && frame-ct.lastFrame <= framesGap) {
//						
//						double distance = Math.abs(f[0] - ct.f.get(ct.lastFrame)[0]); // use freq distance as a coef
//						//distance = distance * (1/f[1]); // use BW as a coef
//						//distance = distance * (1/(frame - ct.lastFrame)); // use frame distance as a coef
//						
//						if (distance < bestDistance) { // by ommiting the equal sign, a priority is made to lower freq. formants
//							bestIndex = i;
//							bestDistance = distance;
//						}
//					}
//					i++;
//				}
//
//				int curSynthRangeId = findSynthRangeId(f[0]);
//				
//				if (bestIndex != -1) {
//					
//					FormantTrack ft = currentTracks.get(bestIndex);
//					
//					// check if track stays in the same synth 
//					boolean commonSynthId = false;
//					boolean[] commonSynthIds = new boolean[]{false, false, false, false};
//
//					for (int j = 0; j < ft.usedSynths.length; j++) {
//						if (ft.usedSynths[j] == true && ft.usedSynths[j] == synthRange[curSynthRangeId][j]) {
//							commonSynthId = true;
//							commonSynthIds[j] = true;
//						}
//					}
//					
//					if (commonSynthId) {
//						// register formant to nearest current track on existing track
//						ft = currentTracks.get(bestIndex);
//						ft.f.put(frame, new double[] {f[0], f[1]});
//						ft.lastFrame = frame;
//						ft.trackSize = ft.lastFrame-ft.firstFrame+1;
//						ft.usedSynths = commonSynthIds;
//						log.info("track:{} frame:{} range:{} fq:{}", bestIndex, frame, commonSynthIds, f[0]);
//					} else {
//						bestIndex = -1;
//					}
//				}
//				
//				if (bestIndex == -1) {
//					// create new track if formant is too far or if a frequency range is crossed
//					FormantTrack ft = new FormantTrack();
//					ft.f.put(frame, new double[] {f[0], f[1]});
//					ft.firstFrame = frame;
//					ft.lastFrame = frame;
//					ft.trackSize = 1;
//					ft.usedSynths = synthRange[curSynthRangeId];
//					currentTracks.add(ft);
//					log.info("new track:{} frame:{} fq:{}", currentTracks.size()-1, frame, f[0]);
//				}
//			}				
//		}
//		
//		// close ended tracks for the current frame
//		// by moving thoses to completed track list
//		for (int i = 0; i < currentTracks.size(); i++)
//		{
//			FormantTrack ft = currentTracks.get(i);
//			if (frame-ft.lastFrame > framesGap) {
//				for (int s=0; s < 4; s++) {
//					if (ft.usedSynths[s]) {
//						synthTracks.get(s).add(ft);
//					}
//				}
//				completedTracks.add(ft);
//			}
//		}
//		
//		for (int i = 0; i < completedTracks.size(); i++)
//		{
//			FormantTrack ft = completedTracks.get(i);
//			if (currentTracks.contains(ft)) {
//				currentTracks.remove(ft);
//			}
//		}
//		
//		
//		frame++;
//	}
//	
//	// close latest tracks
//	for (int i = 0; i < currentTracks.size(); i++)
//	{
//		FormantTrack ft = currentTracks.get(i);
//		for (int s=0; s < 4; s++) {
//			if (ft.usedSynths[s]) {
//				synthTracks.get(s).add(ft);
//			}
//		}
//		completedTracks.add(ft);
//	}
//	currentTracks.clear();
//}
//
//public static void filterSynths(List<FormantTrack> completedTracks) {
//	
//	int[][] slots = new int[4][formants.size()];
//	int longestTrack, selectedSynthId;
//	
//	do {
//		longestTrack = -1;
//		selectedSynthId = -1;
//		int maxSize = 0;
//		
//		for (int i = 0; i < completedTracks.size(); i++)
//		{
//			FormantTrack ft = completedTracks.get(i);
//			if (ft.synth == -1) {			
//				for (int k=0; k < ft.usedSynths.length; k++) {
//					if (ft.usedSynths[k]) {
//						
//						// check if range is not already occupied	
//						boolean occupied = false;
//						for (int j = ft.firstFrame; j <= ft.lastFrame; j++) {
//							if (slots[k][j] > 0) {
//								occupied = true;
//								break;
//							}
//						}
//						if (!occupied && ft.trackSize >= maxSize) {
//							longestTrack = i;
//							selectedSynthId = k;
//							maxSize = ft.trackSize;
//							break;
//						}
//					}
//				}
//			}
//		}
//
//		// keep longest track
//		if (longestTrack != -1) {
//			FormantTrack ft = completedTracks.get(longestTrack);
//			ft.synth = selectedSynthId;
//			for (int j = ft.firstFrame; j <= ft.lastFrame; j++) {
//				slots[ft.synth][j]++;
//			}
//		}
//		
//	} while (longestTrack != -1);
//}
}
