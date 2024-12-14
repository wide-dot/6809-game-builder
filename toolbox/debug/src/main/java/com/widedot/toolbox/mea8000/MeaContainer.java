package com.widedot.toolbox.mea8000;

import java.util.ArrayList;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class MeaContainer {
	
	public ArrayList<MeaFrame> frames;
	
	// linearized data
	public int nbFrames;
	public double[][] fm;
	public double[][] bw;
	public double[]   p;
	public boolean[]  n;
	public double[]   ampl;
	public double[]   amplDisplay;
	
	public MeaContainer() {
		frames = new ArrayList<MeaFrame>();
	}
	
	public void compute() {
		int nbFrames = frames.size();
		fm = new double[4][nbFrames];
		bw = new double[4][nbFrames];
		p = new double[nbFrames];
		n = new boolean[nbFrames];
		ampl = new double[nbFrames];
		amplDisplay = new double[nbFrames];
		
		// pitch
		for (int j=0; j<nbFrames; j++) {
			p[j] = frames.get(j).pitch;
		}
		log.info("  - pitch: {}", p);
		
		// noise
		for (int j=0; j<nbFrames; j++) {
			n[j] = frames.get(j).noise;
		}
		log.info("  - noise: {}", n);
		
		// ampl
		for (int j=0; j<nbFrames; j++) {
			if (frames.get(j).ampl == 0) {
				ampl[j] = 0;
			} else {
				ampl[j] = frames.get(j).ampl;
				amplDisplay[j] = 0.10+frames.get(j).ampl/2000.0;
			}
		}
		
		log.info("  - ampl: {}", ampl);
		
		// freq/bandwidth
		for (int f = 0; f < 4; f++) {
			for (int j = 0; j < nbFrames; j++) {
				fm[f][j] = frames.get(j).fm[f];
				bw[f][j] = frames.get(j).bw[f];
			}
			log.info("  - fm{}: {}", f, fm[f]);
			log.info("  - bw{}: {}", f, bw[f]);
		}
	}
}
