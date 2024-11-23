package com.widedot.toolbox.mea8000.dsp;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;

import org.apache.commons.math3.analysis.interpolation.SplineInterpolator;
import org.apache.commons.math3.analysis.polynomials.PolynomialSplineFunction;
import org.tribuo.Example;
import org.tribuo.MutableDataset;
import org.tribuo.clustering.ClusterID;
import org.tribuo.clustering.ClusteringFactory;
import org.tribuo.clustering.hdbscan.HdbscanModel;
import org.tribuo.clustering.hdbscan.HdbscanTrainer;
import org.tribuo.datasource.ListDataSource;
import org.tribuo.impl.ArrayExample;
import org.tribuo.provenance.SimpleDataSourceProvenance;

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
	
	private static double[] freqRangeAvg = new double[] {400.0, 1250.0, 2500.0, 3500.0};
	private static double[] freqRangeAmpl = new double[] {400.0, 750.0, 500.0, 0.0};
	private static double[] freqRange = new double[] {427.5, 1073.5, 1139.5, 3450, Double.MAX_VALUE}; // FM1, FM1+FM2, FM2, FM2+FM3, FM4
	private static boolean[][] synthRange = new boolean[][] {
		new boolean[]{true,  false, false, false}, 
		new boolean[]{true,  true,  false, false}, 
		new boolean[]{false, true,  false, false}, 
		new boolean[]{false, true,  true,  false}, 
		new boolean[]{false, false, false, true}};
	
	// formant analysis
	private static List<Float> pitches = new ArrayList<>();           // for each frame, gives all pitches
	private static SynthTrack[] tracks = new SynthTrack[4];
	
	// plots for rendering clusters on graph
	public static List<double[]> xf;
	public static List<double[]> yf;
	
	// plots for rendering curve on graph
	public static List<double[]> xCurves;
	public static List<double[]> yCurves;
	
	public static class SynthTrack {
		public List<List<double[]>> formants;
		public List<List<Integer>> labels;
		public HashSet<Integer> labelsSet;
		public HashMap<Integer, Integer> labelsSize;
		
		public PolynomialSplineFunction spline;
		public int nbFormants;
		
		public SynthTrack() {
			formants = new ArrayList<>();
			labels = new ArrayList<>();
			labelsSize = new HashMap<Integer, Integer>();
		}
	
		public void compute() {
			
			labels.clear();
			
			String[] featureNames = new String[]{"frame", "frequency", "bandwith"};
			List<Example<ClusterID>> data = new ArrayList<>();
			nbFormants=0;
			for (List<double[]> formantFrame : formants) {
				for (double[] formant : formantFrame) {
					data.add(new ArrayExample<ClusterID>(new ClusterID(nbFormants), featureNames, formant));
					nbFormants++;
				}
			}

			var datasource = new ListDataSource<ClusterID>(data, new ClusteringFactory(), new SimpleDataSourceProvenance("Formants", new ClusteringFactory()));
			var dataset = new MutableDataset<ClusterID>(datasource);
			
			var trainer = new HdbscanTrainer(30);
			var model = trainer.train(dataset);
			var clusterLabels = ((HdbscanModel) model).getClusterLabels();
			labelsSet = new HashSet<>(clusterLabels);
			System.out.println(labelsSet);
			
			int i = 0;
			for (List<double[]> formantFrame : formants) {
				List<Integer> labelFrame = new ArrayList<Integer>();
				labels.add(labelFrame);
				for (int j=0; j<formantFrame.size(); j++) {
					labelFrame.add(clusterLabels.get(i));
					Integer count = labelsSize.get(clusterLabels.get(i));
					if (count == null) {
						count = 1;
					} else {
						count++;
					}
					labelsSize.put(clusterLabels.get(i), count);
					i++;
				}
			}
		}
		
		public void computePolynomialSplineFunction(int synth, double weightParameter, double speed, int smoothRange) {

			// TODO: Add as param
        	double rail=1.0;
        	double railRange=175;
        	int railAhead=10;
        	//----------
        	
			double InitialTargetValue = freqRangeAvg[synth];
			double targetValue = InitialTargetValue;
			double mintargetValue = targetValue-freqRangeAmpl[synth];
			double maxtargetValue = targetValue+freqRangeAmpl[synth];
			
	        // Flatten input and aggregate points
			// Ignore first list, it contains noise detected by clustering
	        List<double[]> points = new ArrayList<>();
	        for (int l = 1; l < formants.size(); l++) {
	            points.addAll(formants.get(l));
	        }
	        
	        // Sort points by x-value
	        points.sort(Comparator.comparingDouble(a -> a[0]));

	        // Weighted averaging of y-values for each x
	        List<Double> xList = new ArrayList<>();
	        List<Double> yList = new ArrayList<>();

	        double startX = points.get(0)[0];
	        double currentX = 0;
	        double currentY = InitialTargetValue;
	        double weightedSum1 = 0;
	        double weightSum1 = 0;
	        double weightedSum2 = 0;
	        double weightSum2 = 0;

	        int nextP = 0;
	        boolean nextFound = false;
	        double[] point;
	        for (int p = 0; p < points.size(); p++) {
	        	point = points.get(p);
	        	currentX = point[0];
	        	
	        	if (!nextFound && point[0] != startX) {
	        		nextP = p;
	        		nextFound = true;
	        	}
	        	
	        	// TODO : arreter le go back et faire une sous boucle ...
	        	// ça evitera la merde en fin de parcours ...
	        	// s'assurer avec le Zero.wav qu'on a un complément linéaire si pas de points en fin de signal
	        	
	        	if (point[0] > startX+railAhead) {
	            	
		            log.info("synth:{} frame:{} track:{} {} next:{} {}", synth, currentX, weightSum1, weightedSum1 / weightSum1, weightSum2, weightedSum2 / weightSum2);
		            currentY = 0;
		            double d = 0;
		            if (weightSum1 > 0.01) {
		            	currentY += (weightedSum1 / weightSum1);
		            	d++;
		            }
		            if (weightSum2 > 0.01) {
		            	currentY += (weightedSum2 / weightSum2)*rail;
		            	d+=rail;
		            }
		            currentY = currentY / d;
	            	
	            	if (currentY > 0) {
		                xList.add(startX);
		                yList.add(currentY);
		    	        targetValue = Math.min(Math.max(targetValue+(currentY-targetValue)*speed, mintargetValue), maxtargetValue);
	            	} else {
	            		// if no computed value, return slowly to initial target
	            		targetValue = Math.min(Math.max(InitialTargetValue+(currentY-InitialTargetValue)*speed, mintargetValue), maxtargetValue);
	            	}
		    	        
	                // Reset for the new x value
	                p = nextP; // go back in the for loop
		        	point = points.get(p);
	                startX = point[0];
		        	currentX = point[0];
	                log.info("go back:{} p:{}", startX, p);
	                weightedSum1 = 0;
	                weightSum1 = 0;
	                weightedSum2 = 0;
	                weightSum2 = 0;
	                nextFound = false;
	            }
	            
	            if (Math.abs(point[1]-currentY) < railRange) {
		            double weight = (1.0/(currentX-startX+1))/Math.abs(point[1]-currentY);
		            weightedSum2 += point[1] * weight;
		            weightSum2 += weight;
	            }
	            if (!nextFound) {
		            double weight = Math.exp(-weightParameter * Math.abs(point[1] - targetValue));
		            weightedSum1 += point[1] * weight;
		            weightSum1 += weight;
	            }
	        }
	        
	        // Finalize the last point
            currentY = 0;
            double d = 0;
            if (weightSum1 > 0.01) {
            	currentY += (weightedSum1 / weightSum1);
            	d++;
            }
            if (weightSum2 > 0.01) {
            	currentY += (weightedSum2 / weightSum2)*rail;
            	d+=rail;
            }
            currentY = currentY / d;
        	
        	if (currentY == 0) currentY = InitialTargetValue;
            xList.add(startX);
            yList.add(currentY);
	        
	        List<Double> smoothedYList = applySmoothing(yList, smoothRange);

	        // Convert to arrays
	        double[] x = xList.stream().mapToDouble(Double::doubleValue).toArray();
	        double[] y = smoothedYList.stream().mapToDouble(Double::doubleValue).toArray();

	        // Create the spline
	        SplineInterpolator interpolator = new SplineInterpolator();
	        spline = interpolator.interpolate(x, y);
	    }

	    // Calculate weight based on distance to the target value with a parameter
	    private static double calculateWeight(double y, double target, double parameter) {
	        // Example weight: Exponential decay
	        return Math.exp(-parameter * Math.abs(y - target));
	    }
	    
	    // Apply simple moving average smoothing to the weighted values
	    private static List<Double> applySmoothing(List<Double> data, int windowSize) {
	        List<Double> smoothedData = new ArrayList<>();
	        int halfWindow = windowSize / 2;

	        if (halfWindow>0) {
		        for (int i = 0; i < data.size(); i++) {
		            double sum = 0;
		            int count = 0;
	
		            // Average neighboring values within the window
		            for (int j = Math.max(0, i - halfWindow); j <= Math.min(data.size() - 1, i + halfWindow); j++) {
		                sum += data.get(j);
		                count++;
		            }
	
		            smoothedData.add(sum / count);
		        }
		        return smoothedData;
	        }

	        return data;
	    }
	}
	
	public static void compute(float[] audioIn) {
	
		xf = new ArrayList<double[]>();	
		yf = new ArrayList<double[]>();	
		xCurves = new ArrayList<double[]>();	
		yCurves = new ArrayList<double[]>();	
		pitches.clear();
		
        for (int synth=0; synth<4; synth++) {
        	tracks[synth] = new SynthTrack();
        }
		
		// process all frames for pitch, freq and bandwidth
        double frame = 0;
		for (int s=0; s<audioIn.length; s+=SAMPLE_FRAME) {
			
			// find frame pitch
			pitches.add(YIN.estimatePitch(Arrays.copyOfRange(audioIn, s, s+SAMPLE_WINDOW_PITCH), SAMPLE_RATE));
			
			// window
			float[] x = Window.hamming(Arrays.copyOfRange(audioIn, s, s+SAMPLE_WINDOW_FREQ));
			
			// pre-Emphasis filtering
			x = Filter.preEmphasis(x);
		
	        List<List<double[]>> formantsBySynth = new ArrayList<List<double[]>>();
	        for (int synth=0; synth<4; synth++) {
	        	formantsBySynth.add(new ArrayList<double[]>());
	        }
	        double[] el;
	        
	        // process a sound frame
			for (int nodes=22; nodes<=32; nodes++) {
				
		    	// get list of formant (frequency, bandwidth) pairs
		        double[][] f = LPC.estimateFormants(x, nodes, SAMPLE_RATE);
		
		        for(int i = 0; i < f.length; i++) {
		        	
		        	// filter valid formants
		        	if(f[i][0] > 140.0 && f[i][0] < 4000.0 && f[i][1] <= 125) {
		        		
		        		// saves each valid formants ...
		    			el = new double[3];
		    			el[0] = frame;
		    			el[1] = f[i][0];
		    			el[2] = f[i][1];
		    			
		    			// ... in 4 separate synth tracks
		    			boolean[] isInRange = getSynthRange(f[i][0]);
		    			for (int synth=0; synth<4; synth++) {
		    				if (isInRange[synth]) {
		    					formantsBySynth.get(synth).add(el);
		    				}
		    			}
		        	}
		        }
			}
			
			// save each frames
	        for (int synth=0; synth<4; synth++) {
	        	tracks[synth].formants.add(formantsBySynth.get(synth));
	        }
	        frame++;
		}
		
		// compute clustering of each tracks
        for (int synth=0; synth<4; synth++) {
        	tracks[synth].compute();
        	tracks[synth].computePolynomialSplineFunction(synth, 0.01, 0.001, 0);
        }
        
        computePlots(frame);
	}
		
	private static boolean[] getSynthRange(double f) {
		int i = 0;
		while (i < freqRange.length && f >= freqRange[i]) {
			i++;
		}
		return synthRange[i];
	}
	
	public static void computePlots(double nbFrames) {

		for (int t = 0; t < tracks.length; t++) {
			double start = Double.MAX_VALUE;
			double len = 0;
			for (Integer label : tracks[t].labelsSet) {
				double[] xfd = new double[tracks[t].labelsSize.get(label)];
				xf.add(xfd);
				double[] yfd = new double[tracks[t].labelsSize.get(label)];
				yf.add(yfd);
				
				int i=0, x=0, y=0;
				for(List<Integer> frameLabels : tracks[t].labels) {
					int j=0;
					for (Integer curLabel : frameLabels) {
						if (curLabel==label) {
							xfd[x] = tracks[t].formants.get(i).get(j)[0];
							yfd[y] = tracks[t].formants.get(i).get(j)[1];
							
							if (xfd[x] < start) {
								start = xfd[x]; 
							}
							
							if (xfd[x] > len) {
								len = xfd[x];
							}
							x++;
							y++;
						}
						j++;
					}
					i++;
				}
			}
		}
		
		for (int t = 0; t < tracks.length; t++) {
			
			double[] xfd = new double[(int)nbFrames];
			xCurves.add(xfd);
			double[] yfd = new double[(int)nbFrames];
			yCurves.add(yfd);
			
			boolean firstFound = false;
			double lastValue = freqRangeAvg[t]; // average value will be used if all values are undefined
			for (int i=0; i < xfd.length; i++) {
				
				xfd[i] = i;
				if (tracks[t].spline.isValidPoint(i)) {
					
					lastValue = tracks[t].spline.value(i);
					yfd[i] = lastValue;

					// init starting values if undefined
					if (!firstFound) {
						firstFound = true;
						for (int j=i-1; j >= 0; j--) {
							yfd[j] = lastValue;
						}
					}
				} else {
					// init ending values if undefined
					yfd[i] = lastValue;
				}
			}
		}
		
		ImPlot.setNextAxesToFit();
	}
	
	
//	public static void computePlots(List<List<double[]>> formants) {
//		
//		// compute length for array allocation
//		// formant plots
//		int[] fl = new int[4];
//		for (int i=0; i<4; i++) {
//			fl[i]=0;
//		}
//		
//		for(List<double[]> entry : formants) {
//			for (double[] f : entry) {
//				if (f[1] < (Mea8000Decoder.BW_TABLE[3]+Mea8000Decoder.BW_TABLE[2])/2) {
//					fl[0]++;
//				} else if (f[1] < (Mea8000Decoder.BW_TABLE[2]+Mea8000Decoder.BW_TABLE[1])/2) {
//					fl[1]++;
//				} else if (f[1] < (Mea8000Decoder.BW_TABLE[1]+Mea8000Decoder.BW_TABLE[0])/2) {
//					fl[2]++;
//				} else {
//					fl[3]++;
//				}
//			}
//		}
//
//		xf = new double[fl.length][];
//		yf = new double[fl.length][];		
//		
//		for (int i=0; i<fl.length; i++) {
//			xf[i] = new double[fl[i]];
//			yf[i] = new double[fl[i]];
//		}
//
//		int[] i = new int[fl.length];
//		double frame = 0;
//		for(List<double[]> entry : formants) {
//			for (double[] f : entry) {
//				if (f[1] < (Mea8000Decoder.BW_TABLE[3]+Mea8000Decoder.BW_TABLE[2])/2) {
//					xf[0][i[0]] = frame;
//					yf[0][i[0]++] = f[0];
//				} else if (f[1] < (Mea8000Decoder.BW_TABLE[2]+Mea8000Decoder.BW_TABLE[1])/2) {
//					xf[1][i[1]] = frame;
//					yf[1][i[1]++] = f[0];
//				} else if (f[1] < (Mea8000Decoder.BW_TABLE[1]+Mea8000Decoder.BW_TABLE[0])/2) {
//					xf[2][i[2]] = frame;
//					yf[2][i[2]++] = f[0];
//				} else {
//					xf[3][i[3]] = frame;
//					yf[3][i[3]++] = f[0];
//				}
//			}
//			frame++;
//		}
//		
//		ImPlot.setNextAxesToFit();
//	}
//	
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
