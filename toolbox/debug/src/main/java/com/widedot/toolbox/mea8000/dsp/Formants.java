package com.widedot.toolbox.mea8000.dsp;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import funkatronics.code.tactilewaves.dsp.toolbox.Filter;
import funkatronics.code.tactilewaves.dsp.toolbox.LPC;
import funkatronics.code.tactilewaves.dsp.toolbox.Window;
import funkatronics.code.tactilewaves.dsp.toolbox.YIN;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Formants {

	public static final int SAMPLE_SIZE_IN_BYTES = 2;
	public static final int SAMPLE_SIZE_IN_BITS = SAMPLE_SIZE_IN_BYTES*8;
	public static final int SAMPLE_RATE = 64000;
	public static final int CHANNELS = 1;
	public static final boolean BIG_ENDIAN = true;
	
	private static final int SAMPLE_1MS = SAMPLE_RATE/1000;
	private static final int SAMPLE_STEP = SAMPLE_1MS*8;
	private static final int SAMPLE_FRAME = SAMPLE_1MS*8;
	private static final int SAMPLE_WINDOW_FREQ = SAMPLE_1MS*64;
	private static final int SAMPLE_WINDOW_PITCH = SAMPLE_1MS*32;
	
	public static Map<Double, List<double[]>> formants = new HashMap<>();
	public static Map<Double, Float> pitch = new HashMap<>();
	
	private Formants() {};
	
	public static void compute(float[] audioIn) {
		
		formants.clear();
		pitch.clear();
		
		double frame = (double) SAMPLE_WINDOW_FREQ / (double) SAMPLE_FRAME / 2.0;
		
		// process all frames for pitch, freq and bandwidth
		for (int s=0; s<audioIn.length; s+=SAMPLE_STEP) {
			
			// find frame pitch
			pitch.put(frame, YIN.estimatePitch(Arrays.copyOfRange(audioIn, s, s+SAMPLE_WINDOW_PITCH), SAMPLE_RATE));
			
			// window
			float[] x = Window.hamming(Arrays.copyOfRange(audioIn, s, s+SAMPLE_WINDOW_FREQ));
			
			// pre-Emphasis filtering
			x = Filter.preEmphasis(x);
			
	    	// get list of formant (frequency, bandwidth) pairs
	        double[][] f = LPC.estimateFormants(x, 26, SAMPLE_RATE);

	        List<double[]> a;
	        double[] el;
	        for(int i = 0; i < f.length; i++) {
	        	
	        	// keep valid formants
	        	if(f[i][0] > 140.0 && f[i][0] < 4000.0 && f[i][1] < 800.0) {
	        		
        			el = new double[2];
        			el[0] = f[i][0];
        			el[1] = f[i][1];
        			
		        	if (formants.containsKey(frame)) {
		        		a = formants.get(frame);
		        	} else {
		        		a = new ArrayList<double[]>();
		        		formants.put(frame, a);
		        	}
        			
		        	a.add(el);
	        	}
	        }
	        
			frame += ((double) SAMPLE_STEP / (double) SAMPLE_FRAME);
			log.info("frame: {}", frame);
		}
	}
}
