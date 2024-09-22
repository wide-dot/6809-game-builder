package com.widedot.toolbox.mea8000.ui;

import imgui.extension.implot.ImPlot;
import imgui.extension.implot.flag.ImPlotStyleVar;
import imgui.type.ImBoolean;

public class AudioSpectrum {

	public static double[] xs;
	public static double[][] yfm;
	public static double[][] ybw1;
	public static double[][] ybw2;
	
	static {
		ImPlot.createContext();
	}

	public static void show(ImBoolean showImGui) {
		
		if (ImPlot.beginPlot("Audio Spectrum")) {
			
			if (yfm != null) {
				for (int i=0; i<yfm.length; i++) {
					ImPlot.pushStyleVar(ImPlotStyleVar.FillAlpha, 0.25f);
					ImPlot.plotShaded("FM"+i, xs, ybw1[i], ybw2[i], yfm[i].length);
					ImPlot.plotLine("FM"+i, xs, yfm[i], yfm[i].length);
					ImPlot.popStyleVar();
				}
			}
			
			ImPlot.endPlot();
		}

	}
	
	public static void compute(double[][] fm, double[][] bw) {
		
		if (fm != null && fm[0] != null) {
			
			// set x axis values
			
			xs = new double[fm[0].length];
			
			for (int x=0; x<fm[0].length; x++) {
				xs[x] = (double) x;
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
	}
}
