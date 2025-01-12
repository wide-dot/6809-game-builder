package com.widedot.toolbox.mea8000.dsp;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Random;

//import org.tribuo.Example;
//import org.tribuo.MutableDataset;
//import org.tribuo.clustering.ClusterID;
//import org.tribuo.clustering.ClusteringFactory;
//import org.tribuo.clustering.hdbscan.HdbscanModel;
//import org.tribuo.clustering.hdbscan.HdbscanTrainer;
//import org.tribuo.datasource.ListDataSource;
//import org.tribuo.impl.ArrayExample;
//import org.tribuo.provenance.SimpleDataSourceProvenance;

import com.widedot.toolbox.debug.DataUtil;
import com.widedot.toolbox.mea8000.MeaContainer;
import com.widedot.toolbox.mea8000.MeaFrame;

import funkatronics.code.tactilewaves.dsp.toolbox.Filter;
import funkatronics.code.tactilewaves.dsp.toolbox.LPC;
import funkatronics.code.tactilewaves.dsp.toolbox.Window;
import funkatronics.code.tactilewaves.dsp.toolbox.YIN;
import imgui.extension.implot.ImPlot;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Formants {

	private static final int SAMPLE_SIZE_IN_BYTES = 2;
	private static final int SAMPLE_SIZE_IN_BITS = 8*SAMPLE_SIZE_IN_BYTES;
	private static final int SAMPLE_RATE = 64000;

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

	public static final double[][] FM_TABLE = {{ 150.0, 162.0, 174.0, 188.0, 202.0, 217.0, 233.0, 250.0, 267.0, 286.0, 305.0, 325.0, 346.0, 368.0, 391.0, 415.0, 440.0, 466.0, 494.0, 523.0, 554.0, 587.0, 622.0, 659.0, 698.0, 740.0, 784.0, 830.0, 880.0, 932.0, 988.0, 1047 },
			{ 440.0, 466.0, 494.0, 523.0, 554.0, 587.0, 622.0, 659.0, 698.0, 740.0, 784.0, 830.0, 880.0, 932.0, 988.0, 1047.0, 1100.0, 1179.0, 1254.0, 1337.0, 1428.0, 1528.0, 1639.0, 1761.0, 1897.0, 2047.0, 2214.0, 2400.0, 2609.0, 2842.0, 3105.0, 3400 },
			{ 1179.0, 1337.0, 1528.0, 1761.0, 2047.0, 2400.0, 2842.0, 3400 },
			{ 3500 }};
	private static double[] FREQ_RANGE_MIN  = {  0.0,   427.5, 1139.5, 3450.0};
	private static double[] FREQ_RANGE_MAX  = {1073.5, 3450.0, 3450.0, 4000.0};
	private static double[] FREQ_RANGE      = {427.5, 1073.5, 1139.5, 3450, Double.MAX_VALUE}; // FM1, FM1+FM2, FM2, FM2+FM3, FM4
	private static boolean[][] SYNTH_RANGE  = {
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
	
	// MEA encoding
	private static ArrayList<ArrayList<MeaFrame>> meaFrames = new ArrayList<ArrayList<MeaFrame>>();
	public static byte[] meaCodes;

	public static class SynthTrack {

		// formants data structure
		// -----------------------
		// the parent List have one element per frame (even if empty)
		// the child List hold all valid formants for a frame
		// a formant is an array of double with : [0]=frame, [1]=frequency, [2]=bandwidth
		public List<List<double[]>> formants;

		// Clustering is obsolete now I think ... 
		public List<List<Integer>> labels;
		public HashSet<Integer> labelsSet;
		public HashMap<Integer, Integer> labelsSize;
		public int nbFormants;

		public List<double[]> audio = new ArrayList<>();           // hold all possible audio versions for a synth based on different mean values.
		public int audioId = 0;                                    // best index in audio table
		public List<double[]> confidence = new ArrayList<>();      // confidence in audio frequency value 0.0-1.0 
		public List<Integer> nbAccuratePoints = new ArrayList<>(); // number of frames where curve is close to cluster points

		public SynthTrack() {
			formants = new ArrayList<>();
			labels = new ArrayList<>();
			labelsSize = new HashMap<Integer, Integer>();
		}

//		public void computeClustering() {
//
//			labels.clear();
//
//			String[] featureNames = new String[]{"frame", "frequency", "bandwith"};
//			List<Example<ClusterID>> data = new ArrayList<>();
//			nbFormants=0;
//			for (List<double[]> formantFrame : formants) {
//				for (double[] formant : formantFrame) {
//					data.add(new ArrayExample<ClusterID>(new ClusterID(nbFormants), featureNames, formant));
//					nbFormants++;
//				}
//			}
//
//			var datasource = new ListDataSource<ClusterID>(data, new ClusteringFactory(), new SimpleDataSourceProvenance("Formants", new ClusteringFactory()));
//			var dataset = new MutableDataset<ClusterID>(datasource);
//
//			var trainer = new HdbscanTrainer(30);
//			var model = trainer.train(dataset);
//			var clusterLabels = ((HdbscanModel) model).getClusterLabels();
//			labelsSet = new HashSet<>(clusterLabels);
//			System.out.println(labelsSet);
//
//			int i = 0;
//			for (List<double[]> formantFrame : formants) {
//				List<Integer> labelFrame = new ArrayList<Integer>();
//				labels.add(labelFrame);
//				for (int j=0; j<formantFrame.size(); j++) {
//					labelFrame.add(clusterLabels.get(i));
//					Integer count = labelsSize.get(clusterLabels.get(i));
//					if (count == null) {
//						count = 1;
//					} else {
//						count++;
//					}
//					labelsSize.put(clusterLabels.get(i), count);
//					i++;
//				}
//			}
//		}

		public void computeAudioSynth(int synth, double weightParameter, double speed, int smoothRange) {

			// TODO: Add as param
			double railScale=0.5;
			double railRange=600;
			int railAhead=50;
			//----------

			// process all solutions with different starting points
			for (int s = 0; s < FM_TABLE[synth].length; s++) {

				int totalFrames = formants.size();
				int counterAccuratePoints = 0;
				double InitialTargetValue = FM_TABLE[synth][s];
				double mintargetValue = FREQ_RANGE_MIN[synth];
				double maxtargetValue = FREQ_RANGE_MAX[synth];
				double targetValue = InitialTargetValue;
				double currentY = InitialTargetValue;
				double lastKnownY = InitialTargetValue;
				//double direction = 0;

				// Weighted averaging of y-values for each frame
				List<Double> yList = new ArrayList<>();
				double[] curConfidence = new double[totalFrames];
				for (int frame = 0; frame < totalFrames; frame++) {

					double weightedSum1 = 0;
					double weightSum1 = 0;
					double weightedSum2 = 0;
					double weightSum2 = 0;

					// Tracking based on floating target value for this synth
					List<double[]> points = formants.get(frame);
					for (int i = 0; i < points.size(); i++) {
						double freq = points.get(i)[1];
						double weight = Math.exp(-weightParameter * Math.abs(freq - (targetValue+InitialTargetValue)/2.0));
						//double weight = Math.exp(-weightParameter * Math.abs(freq - (targetValue + direction)));
						weightedSum1 += freq * weight;
						weightSum1 += weight;
					}

					// Tracking based on averaging of forward frequency values
					for (int forwardFrame = frame; forwardFrame < Math.min(frame+railAhead, totalFrames); forwardFrame++) {
						points = formants.get(forwardFrame);
						for (int i = 0; i < points.size(); i++) {
							double freq = points.get(i)[1];
							if (Math.abs(points.get(i)[1]-currentY) < railRange) {
								double weight = (1.0/Math.pow(forwardFrame-frame+1, 2.0))/Math.pow((Math.abs(freq-currentY)+1), 1.5);
								weightedSum2 += freq * weight;
								weightSum2 += weight;
							}
						}
					}

					// Compute final tracking
					// ----------------------
					double d = 0;
					currentY = 0;

					// ignore tracking methods with unsignificant values
					if (weightSum1 > 0.05) {
						currentY += (weightedSum1 / weightSum1);
						d++;
					}
					if (weightSum2 > 0.00001) {
						currentY += (weightedSum2 / weightSum2)*railScale;
						d+=railScale;
					}

					if (d > 0) {
						// apply tacking
						currentY = currentY / d;
						//targetValue = Math.min(Math.max(currentY+(targetValue-currentY)*speed, mintargetValue), maxtargetValue);
						targetValue = currentY;
					} else {
						// if no computed value for tracking, return slowly to synth mean   
						currentY = Math.min(Math.max(lastKnownY+(InitialTargetValue-lastKnownY)*speed, mintargetValue), maxtargetValue);
						targetValue = currentY;   
					}         	

					//	            	if (synth == 1 && s == 26) {
					//	            		log.info("synth:{} frame:{} y:{} track1:{} {} track2:{} {}", synth, frame, currentY, weightSum1, weightedSum1 / weightSum1, weightSum2, weightedSum2 / weightSum2);
					//	            	}

					// compute accuracy
					points = formants.get(frame);
					double dist = 0;
					double bestDist = Double.MAX_VALUE;
					for (int i = 0; i < points.size(); i++) {
						dist = Math.abs(points.get(i)[1]-currentY);
						if (dist < bestDist) {
							bestDist = dist;
						}
					}
					if (bestDist < 80) {
						counterAccuratePoints++;
						curConfidence[frame] = 1.0;
					} else {
						curConfidence[frame] = 0.0;
					}

					yList.add(currentY);
					//direction = currentY-lastKnownY;
					lastKnownY = currentY;
				}

				List<Double> smoothedYList = applySmoothing(yList, smoothRange);

				// Convert to arrays
				audio.add(smoothedYList.stream().mapToDouble(Double::doubleValue).toArray());
				confidence.add(curConfidence);
				nbAccuratePoints.add(counterAccuratePoints);
			}
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
		int frame = 0;
		for (int s=0; s<audioIn.length; s+=SAMPLE_FRAME) {

			// find frame pitch
			float val = YIN.estimatePitch(Arrays.copyOfRange(audioIn, s, s+SAMPLE_WINDOW_PITCH), SAMPLE_RATE);
			if (val < PITCH_MIN || val > PITCH_MAX) {
				val = -1;
			}
			pitches.add(val);

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
			for (int nodes=28; nodes<=32; nodes++) {

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
			//tracks[synth].computeClustering();
			tracks[synth].computeAudioSynth(synth, 0.01, 0.1, 0);

		}

		findBestCurves();
		computePlots();
		encodeMea(audioIn);
		writeMeaData("./out.mea");
	}

	private static boolean[] getSynthRange(double f) {
		int i = 0;
		while (i < FREQ_RANGE.length && f >= FREQ_RANGE[i]) {
			i++;
		}
		return SYNTH_RANGE[i];
	}

	public static void findBestCurves() {

		// find synth curves with minimal overlapping
		// TODO : find best path quality based on track weight

		int bestScore = -1;
		for (int t0 = 0; t0 < tracks[0].audio.size(); t0++) {
			for (int t1 = 0; t1 < tracks[1].audio.size(); t1++) {
				for (int t2 = 0; t2 < tracks[2].audio.size(); t2++) {
					int score = 0;
					int nbFrames = tracks[0].audio.get(tracks[0].audioId).length; // all length are equals take the first
					for (int x = 0; x < nbFrames; x++) {
						if (Math.abs(tracks[0].audio.get(t0)[x] - tracks[1].audio.get(t1)[x]) < 80.0) score++;
						if (Math.abs(tracks[0].audio.get(t0)[x] - tracks[2].audio.get(t2)[x]) < 80.0) score++;
						if (Math.abs(tracks[1].audio.get(t1)[x] - tracks[2].audio.get(t2)[x]) < 80.0) score++;
					}

					int totalAccPts = tracks[0].nbAccuratePoints.get(t0) + tracks[1].nbAccuratePoints.get(t1) + tracks[2].nbAccuratePoints.get(t2);

					if (totalAccPts-score > bestScore) {
						bestScore = totalAccPts-score;
						tracks[0].audioId = t0;
						tracks[1].audioId = t1;
						tracks[2].audioId = t2;
					}

					//log.info("({}, {}, {}): {} Total Acc Pts {}", FM_TABLE[0][t0], FM_TABLE[1][t1], FM_TABLE[2][t2], score, totalAccPts);
				}
			}
		}

		//		tracks[0].audioId = 4;
		//		tracks[1].audioId = 26;
		//		tracks[2].audioId = 6;
		log.info("Best score ({}, {}, {}): {}", FM_TABLE[0][tracks[0].audioId], FM_TABLE[1][tracks[1].audioId], FM_TABLE[2][tracks[2].audioId], bestScore);
	}

	public static void computePlots() {

		// process formant plots
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

		// process synth curves
		for (int t = 0; t < tracks.length; t++) {
			int nbFrames = tracks[t].audio.get(tracks[t].audioId).length;
			double[] xf = new double[nbFrames];
			for (int x = 0; x < nbFrames; x++) xf[x] = x;
			xCurves.add(xf);
			yCurves.add(tracks[t].audio.get(tracks[t].audioId));
		}

		ImPlot.setNextAxesToFit();
	}

	private static void encodeMea(float[] audioIn) {

		MeaFrame firstFrame = new MeaFrame();
		
		// register starting parameters
		meaFrames.clear();

		//log.info("Pitch list: {}", pitches.toString());
		
		// search for initial pitch
		float startPitch = -1;
		for (int frame = 0; frame < pitches.size(); frame++) {
			startPitch = pitches.get(frame);
			if (startPitch != -1.0) break;
		}
		pitches.set(0, startPitch);
		//log.info("Start pitch: {}", startPitch);
		
		// interpolate pitches when no values (-1)
		int pitchAPos=0, pitchBPos;
		while(pitchAPos < pitches.size()-1) {
			
			// get start and end values
			for (pitchBPos = pitchAPos+1; pitchBPos < pitches.size(); pitchBPos++) {
				if (pitches.get(pitchBPos) != -1.0) break;
			}
			
			// end of table special case 
			if (pitchBPos == pitches.size()) {
				pitchBPos = pitches.size()-1;
				pitches.set(pitchBPos, pitches.get(pitchAPos));
			}
			
			// set the interpolated values
			for (int pos = pitchAPos+1; pos < pitchBPos; pos++) {
				pitches.set(pos, pitches.get(pitchAPos)+(pos-pitchAPos)*((pitches.get(pitchBPos)-pitches.get(pitchAPos))/(pitchBPos - pitchAPos)));
			}
			
			pitchAPos = pitchBPos;
		}
		//log.info("Interpolated pitch list: {}", pitches.toString());		
		
		// first frame is a special case
		// init starting parameters
		firstFrame.pos = 0;
		firstFrame.phi = 0;
		firstFrame.pitch = (int) ((startPitch / 2) * 2);
		setMeaFilters(firstFrame, tracks);
		
		int chunk = 0;
		meaFrames.add(new ArrayList<MeaFrame>());
		meaFrames.get(chunk).add(firstFrame);
		MeaFrame curFrame, lastFrame = firstFrame;
		for (int frame = 0; frame < pitches.size(); frame++) {
			
			curFrame = new MeaFrame();
			curFrame.pos = frame;
		
			setMeaFilters(curFrame, tracks);
			setMeaAmpl(curFrame, tracks, audioIn);
			boolean result = setMeaPitch(pitches.get(frame), curFrame, lastFrame);
			
			// Split stream if pitch increment is too large
			if (!result) {
				chunk++;
				meaFrames.add(new ArrayList<MeaFrame>());
				firstFrame = new MeaFrame(lastFrame);
				firstFrame.pos = 0;
				firstFrame.phi = 0;
				firstFrame.ampl = 0;
				firstFrame.i_ampl = 0;
				meaFrames.get(chunk).add(lastFrame);
			}
			meaFrames.get(chunk).add(curFrame);
			lastFrame = curFrame;
		}
	}

	private static final int QUANT = 512; // samples for 8ms at 64kHz
	private static final int TABLE_LEN = 3600;
	private static final int NOISE_LEN = 8192;
	private static final int F0 = (3840000 / 480); // digital filters work at 8 kHz
	private static final int SUPERSAMPLING = 8; // filtered output is supersampled x 8
	private static final float PITCH_MAX = 510;
	private static final float PITCH_MIN = 1;
	
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

	private static void setMeaAmpl(MeaFrame curFrame, SynthTrack[] tracks, float[] audioIn) {
		
		// match preset values, and set indexes
		int delta, maxDelta;
		maxDelta = Integer.MAX_VALUE;
		
		double rms = (int) (getRMS(audioIn, (curFrame.pos)*SAMPLE_FRAME, SAMPLE_FRAME)*1000);
		double peak = (int) (calculatePeakLevel(audioIn, (curFrame.pos)*SAMPLE_FRAME, SAMPLE_FRAME)*1000);
		int val = (int) ((rms + peak) / 2);

		for (int i = 0; i < AMPL_TABLE.length; i++) {
			delta = Math.abs(val - AMPL_TABLE[i]);
			if (delta < maxDelta) {
				maxDelta = delta;
				curFrame.i_ampl = i;
				curFrame.ampl = AMPL_TABLE[i];
			} else {
				break;
			}
		}
	}
	
	private static double getRMS(float[] ref, int start, int length) {
		
		double rmsRef = 0;
		for (int i = start; i < start+length; i++) {
			if (i < ref.length) {
				double normalizedSample = ref[i] / (Math.pow(2, SAMPLE_SIZE_IN_BITS - 1));
				rmsRef += normalizedSample*normalizedSample;
			}
		}
		
		return Math.sqrt(rmsRef/length);
	}
	
	private static double calculatePeakLevel(float[] ref, int start, int length) {
	    double max = 0.0;
	    for (int i = start; i < start+length; i++) {
	    	if (i < ref.length) {
		        double normalizedSample = Math.abs(ref[i] / (Math.pow(2, SAMPLE_SIZE_IN_BITS - 1)));
		        if (normalizedSample > max) {
		            max = normalizedSample;
		        }
	    	}
	    }
	    return max;
	}
	
	public static void setMeaFilters(MeaFrame curFrame, SynthTrack[] tracks) {
	
		int delta, maxDelta;
	
		// Bandwidth
		// ---------------------------------------------------------------------
	
		// match preset values, and set indexes
		for(int i = 0; i < 4; i++) {
			maxDelta = Integer.MAX_VALUE;
			int val = (int) tracks[i].confidence.get(tracks[i].audioId)[curFrame.pos];
			val = val * BW_TABLE[2];
			for (int j = 0; j < BW_TABLE.length; j++) {
				delta = Math.abs(val - BW_TABLE[j]);
				if (delta < maxDelta) {
					maxDelta = delta;
					curFrame.i_bw[i] = j;
					curFrame.bw[i] = BW_TABLE[j];
				} else {
					break;
				}
			}
		} 
	
		// Frequency
		// ---------------------------------------------------------------------
	
		// match preset values, and set indexes
		for(int i = 0; i < 3; i++) {
			maxDelta = Integer.MAX_VALUE;
			int val = (int) tracks[i].audio.get(tracks[i].audioId)[curFrame.pos];
			for (int j = 0; j < FM_TABLES[i].length; j++) {
				delta = Math.abs(val - FM_TABLES[i][j]);
				if (delta < maxDelta) {
					maxDelta = delta;
					curFrame.i_fm[i] = j;
					curFrame.fm[i] = FM_TABLES[i][j];
				} else {
					break;
				}
			}
		}
		curFrame.i_fm[3] = 0;	
		curFrame.fm[3] = FM4;	
	}
	
	public static boolean setMeaPitch(float pitch, MeaFrame curFrame, MeaFrame lastFrame) {
	
		if (curFrame.noise || pitch == -1) {
			curFrame.pitch = lastFrame.pitch;
			curFrame.noise = true;
			curFrame.i_pi = NOISE_INDEX;
			return true;
		} else {
			curFrame.pitch = (int) pitch;
			int pi = (curFrame.pitch - lastFrame.pitch) >> curFrame.fd; 
			if (pi >= PI_TABLE[17] && pi <= PI_TABLE[15]) {
				curFrame.i_pi = (pi & 0x1f);
				lastFrame.ampl = AMPL_TABLE[lastFrame.i_ampl];
				return true;
			}
			if (false) { // TODO option for one Chunk mode
				int pitchDelta = Math.max(Math.min(pi, PI_TABLE[15]), PI_TABLE[17]);
				curFrame.pitch = lastFrame.pitch + pitchDelta;
				curFrame.i_pi = (pitchDelta & 0x1f);
				lastFrame.ampl = AMPL_TABLE[lastFrame.i_ampl];
				return true;
			}
		}
		
		// new Chunk
		return false;
	}
	
	private static byte[] writeMeaData(String inputPathName) {
		
		ArrayList<byte[]> dataList = new ArrayList<byte[]>();
		meaCodes = new byte[0xFFFFFF];
		
		for (ArrayList<MeaFrame> meaChunk : meaFrames) {
			MeaContainer meaDebug = new MeaContainer();
			meaDebug.frames = meaChunk;
			meaDebug.compute();
			
			//ImString intxtData = new ImString(0x10000);
			int pos = 3; 
			
			// set header pitch
			meaCodes[pos++] = (byte) ((meaChunk.get(0).pitch/2) & 0xff);
			String line = "Header pitch: " + DataUtil.byteToHex(meaCodes[pos-1]) + "\r\n";
			
			for (int frame=1; frame<meaChunk.size(); frame++) {
				
				meaCodes[pos] = 0;
				meaCodes[pos+1] = 0;
				meaCodes[pos+2] = 0;
				meaCodes[pos+3] = 0;
				
	        	// set bandwidths
		        for(int i = 0; i < 4; i++) {
		        	meaCodes[pos] = (byte) (meaCodes[pos] | (byte) (meaChunk.get(frame).i_bw[i] << (6-i*2)));
		        }
		        
		        // set frequencies
	    		meaCodes[pos+2] = (byte) (meaCodes[pos+2] | (byte) ((meaChunk.get(frame).i_fm[0] & 0b11111) << 3));
	    		meaCodes[pos+1] = (byte) (meaCodes[pos+1] | (byte) (meaChunk.get(frame).i_fm[1] & 0b11111));
	    		meaCodes[pos+1] = (byte) (meaCodes[pos+1] | (byte) ((meaChunk.get(frame).i_fm[2] & 0b111) << 5));
		    	
		    	// set amplitude
		    	meaCodes[pos+2] = (byte) (meaCodes[pos+2] | (byte) ((meaChunk.get(frame).i_ampl >> 1) & 0b111));
		    	meaCodes[pos+3] = (byte) (meaCodes[pos+3] | (byte) ((meaChunk.get(frame).i_ampl & 0b1) << 7));
				
		    	// set pitch increment
		    	meaCodes[pos+3] = (byte) (meaCodes[pos+3] | (byte) (meaChunk.get(frame).i_pi & 0b11111));
		    	
		    	line += frame + ": " + DataUtil.bytesToHex(meaCodes, pos, 4) + "\r\n";
		    	
		    	pos += 4;
			}
			
			// update header with total length
			meaCodes[0] = (byte) ((pos & 0xff00) >> 8);
			meaCodes[1] = (byte) (pos & 0xff);
			meaCodes[2] = (byte) 0;
			line = "Length: " + DataUtil.bytesToHex(meaCodes, 0, 2) + "\r\n\r\n" + line + "\r\n";
			//intxtData.set(line);	
			log.info("{}", line);
			
			dataList.add(Arrays.copyOf(meaCodes, pos));	
		}
		
		meaCodes = convertToByteArray(dataList);
		
		try {
			Path path = Path.of(inputPathName);
			Files.write(path, meaCodes);
			log.info("output file: {}", path.toAbsolutePath());
		} catch (IOException e) {
			e.printStackTrace();
		}
		
		return meaCodes;        
	}
	
    public static byte[] convertToByteArray(ArrayList<byte[]> byteArrayList) {
        // Calculate total size
        int totalSize = 0;
        for (byte[] array : byteArrayList) {
            totalSize += array.length;
        }

        // Create a new byte array
        byte[] result = new byte[totalSize];

        // Copy data from each byte[] into the result array
        int currentIndex = 0;
        for (byte[] array : byteArrayList) {
            System.arraycopy(array, 0, result, currentIndex, array.length);
            currentIndex += array.length;
        }

        return result;
    }

}
