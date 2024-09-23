package com.widedot.toolbox.mea8000.ui;

import java.util.List;
import java.util.Map;

import com.widedot.toolbox.mea8000.dsp.Formants;

import imgui.ImVec2;
import imgui.extension.implot.ImPlot;
import imgui.extension.implot.flag.ImPlotStyleVar;
import imgui.type.ImBoolean;

public class AudioSpectrum {

	//  x axis - frame
	public static double[] xs;
	
	// pitch
	public static double[] yp;
	
	// fm/bw
	public static double[][] yfm;
	public static double[][] ybw1;
	public static double[][] ybw2;
	
	// amplitude
	public static double[] ampl;
	
	// noise
	public static double[] xn;
	public static double[] yn;
	
	// formant plots
	public static double[] xf;
	public static double[] yf;
	
	static {
		ImPlot.createContext();
	}

	public static void show(ImBoolean showImGui) {

		if (ImPlot.beginPlot("Audio Spectrum", new ImVec2(-1,-1))) {
		
			if (yfm != null) {
				
				double[] xa  = new double[2];
				double[] ya1 = new double[2];
				double[] ya2 = new double[2];
				
				for (int i=0; i<ampl.length; i++) { 
					ya1[0] = 4000;
					ya1[1] = 4000;
					ya2[0] = 0;
					ya2[1] = 0;
					xa[0] = i-0.5;
					xa[1] = i+0.5;
					ImPlot.pushStyleVar(ImPlotStyleVar.FillAlpha, (float)ampl[i]);
					ImPlot.plotShaded("Amplitude", xa, ya1, ya2, xa.length);
					ImPlot.popStyleVar();
				}
				
				for (int i=0; i<yfm.length; i++) {
					ImPlot.pushStyleVar(ImPlotStyleVar.FillAlpha, 0.5f);
					ImPlot.plotShaded("FM"+i, xs, ybw1[i], ybw2[i], yfm[i].length);
					ImPlot.plotLine("FM"+i, xs, yfm[i], yfm[i].length);
					ImPlot.popStyleVar();
				}
				
				ImPlot.plotLine("Pitch", xs, yp, yp.length);
				ImPlot.plotScatter("Noise", xn, yn, yn.length);
			}
			
			if (xf != null) {
				ImPlot.plotScatter("Formants", xf, yf, xf.length);
			}

			ImPlot.endPlot();
		}

	}
	
	public static void compute(double[] p, boolean[] n, double[] a, double[][] fm, double[][] bw) {
		
		if (fm != null && fm[0] != null) {
			
			// set y axis values for ampl
			ampl = new double[a.length];
			
			for (int i=0; i<a.length; i++) {
				ampl[i] = a[i];
			}
			
			// set x axis values
			xs = new double[fm[0].length];
			
			for (int x=0; x<fm[0].length; x++) {
				xs[x] = (double) x;
			}
			
			// set y axis values for pitch
			yp = new double[p.length];
			
			for (int i=0; i<p.length; i++) {
				yp[i] = p[i];
			}
			
			// set x and y axis values for noise (displayed as point on pitch line)
			int noiseLength = 0;
			for (int i=0; i<n.length; i++) {
				if (n[i]) {
					noiseLength++;
				}
			}
			
			xn = new double[noiseLength];
			yn = new double[noiseLength];
			
			int j=0;
			for (int i=0; i<n.length; i++) {
				if (n[i]) {
					xn[j] = i;
					yn[j] = p[i];
					j++;
				}
			}
			
			for (int i=0; i<p.length; i++) {
				yp[i] = p[i];
			}
		
			// set y axis values for each freq modulator
			double delta;
			yfm = new double[fm.length][]; 
			ybw1 = new double[fm.length][];
			ybw2 = new double[fm.length][];
			
			for (int f=0; f<fm.length; f++) {
				if (fm[f] != null) {

					yfm[f] = new double[fm[f].length]; 
					ybw1[f] = new double[fm[f].length];
					ybw2[f] = new double[fm[f].length];
					
					for (int i=0; i<fm[f].length; i++) {
						yfm[f][i] = fm[f][i];
						
						if (bw != null && bw[f] != null && i < bw[f].length) {
							delta = bw[f][i]/2;
						} else {
							delta = 0;
						}
						
						ybw1[f][i] = fm[f][i] + delta;
						ybw2[f][i] = fm[f][i] - delta;
					}
				}
				
			}
		}
		
		ImPlot.setNextAxesToFit();
	}
	
	public static void compute(Map<Double, List<double[]>> formants, int length) {
		
		xf = new double[length];
		yf = new double[length];
		int i = 0;
		for(Map.Entry<Double, List<double[]>> entry : formants.entrySet()) {
			for (double[] d : entry.getValue()) {
				xf[i] = entry.getKey();
				yf[i] = d[0];
				i++;
			}
		}
		
		ImPlot.setNextAxesToFit();
	}
}
