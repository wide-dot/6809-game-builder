package com.widedot.toolbox.mea8000;

import java.util.ArrayList;

public class SampleData {
	
	// TODO User should load this data from .mea file

	// sample data of "Bonjour" from "Parole et Micros (Cédric/Nathan)"
	private static final byte[] bonjour = new byte[]{
			//(byte) 0x00, (byte) 0xB8,
			(byte) 0x3C,
			(byte) 0x44, (byte) 0xB6, (byte) 0x28, (byte) 0x10,
			(byte) 0x3C,
			(byte) 0xC4, (byte) 0x2F, (byte) 0x32, (byte) 0xB0, (byte) 0xC5, (byte) 0xAE, (byte) 0x2B, (byte) 0xA0,
			(byte) 0xC4, (byte) 0xB3, (byte) 0x34, (byte) 0xA0, (byte) 0x55, (byte) 0xAD, (byte) 0x6E, (byte) 0xA2, (byte) 0x5B, (byte) 0xAD, (byte) 0x7E, (byte) 0xA4, (byte) 0x5A, (byte) 0xA4, (byte) 0x9E, (byte) 0x26,
			(byte) 0x59, (byte) 0xA4, (byte) 0xA6, (byte) 0x2A, (byte) 0x59, (byte) 0xA5, (byte) 0x9E, (byte) 0xAC, (byte) 0x45, (byte) 0xAC, (byte) 0x96, (byte) 0xA7, (byte) 0x14, (byte) 0xA8, (byte) 0x7E, (byte) 0xA3,
			(byte) 0x55, (byte) 0xAE, (byte) 0x66, (byte) 0xA0, (byte) 0x20, (byte) 0xB0, (byte) 0x56, (byte) 0xBE, (byte) 0x11, (byte) 0xB3, (byte) 0x56, (byte) 0xB5, (byte) 0x1A, (byte) 0xB3, (byte) 0x56, (byte) 0x36,
			(byte) 0x45, (byte) 0xB5, (byte) 0x56, (byte) 0x30, (byte) 0x45, (byte) 0xB7, (byte) 0x57, (byte) 0x30, (byte) 0x05, (byte) 0xB6, (byte) 0x57, (byte) 0x30, (byte) 0x15, (byte) 0xB3, (byte) 0x56, (byte) 0xB1,
			(byte) 0x58, (byte) 0xB4, (byte) 0x5E, (byte) 0x31, (byte) 0x54, (byte) 0xB2, (byte) 0x5E, (byte) 0x3D, (byte) 0x96, (byte) 0x91, (byte) 0x65, (byte) 0xBD, (byte) 0x96, (byte) 0xB0, (byte) 0x55, (byte) 0x3C,
			(byte) 0x97, (byte) 0xB0, (byte) 0x55, (byte) 0x3E, (byte) 0x9A, (byte) 0xAF, (byte) 0x4C, (byte) 0xBF, (byte) 0x9A, (byte) 0xAE, (byte) 0x4C, (byte) 0x3F, (byte) 0xA6, (byte) 0xAD, (byte) 0x44, (byte) 0x3E,
			(byte) 0xA5, (byte) 0xAC, (byte) 0x4B, (byte) 0xA0, (byte) 0x95, (byte) 0xAE, (byte) 0x4B, (byte) 0x30, (byte) 0x95, (byte) 0xAD, (byte) 0x4B, (byte) 0x30, (byte) 0x91, (byte) 0xAE, (byte) 0x53, (byte) 0x30,
			(byte) 0x50, (byte) 0xAC, (byte) 0x53, (byte) 0x30, (byte) 0x80, (byte) 0xAF, (byte) 0x53, (byte) 0x20, (byte) 0xD8, (byte) 0xAE, (byte) 0x5B, (byte) 0x20, (byte) 0xA6, (byte) 0xAE, (byte) 0x5B, (byte) 0xA0,
			(byte) 0x69, (byte) 0xAF, (byte) 0x63, (byte) 0xA0, (byte) 0xAD, (byte) 0xAE, (byte) 0x7C, (byte) 0x20, (byte) 0x69, (byte) 0xAE, (byte) 0x84, (byte) 0xA0, (byte) 0x24, (byte) 0xAD, (byte) 0xD4, (byte) 0xB0,
			(byte) 0x51, (byte) 0xB0, (byte) 0xF4, (byte) 0x30, (byte) 0x32, (byte) 0x90, (byte) 0xC4, (byte) 0x30, (byte) 0x70, (byte) 0xB1, (byte) 0xC4, (byte) 0xB0, (byte) 0x64, (byte) 0xB3, (byte) 0xB4, (byte) 0xB0,
			(byte) 0x62, (byte) 0xB3, (byte) 0x8B, (byte) 0xB0, (byte) 0x62, (byte) 0xB3, (byte) 0x88, (byte) 0x30};
	
	public static double[][] fm;
	public static double[][] bw;
	public static double[]   p;
	public static boolean[]  n;
	public static double[]   ampl;
	
	// TODO : add a fd array for variable frame duration => and upsample to 8ms frame
	
	private SampleData() {};
	
	static {
		ArrayList<MeaFrame> frames = new ArrayList<MeaFrame>();
		int i=0;
		int pitch=0;
		int i_ampl=0;
		while (i<bonjour.length) {
			if (i_ampl==0) pitch=bonjour[i++] * 2;
			frames.add(Mea8000Decoder.decodeFrame(bonjour, i, pitch));
			i_ampl = frames.get(frames.size()-1).i_ampl;
			pitch = frames.get(frames.size()-1).pitch;
			i += 4;
		}
		
		int nbFrames = frames.size();
		
		// pitch
		p = new double[nbFrames];
		
		for (int j=0; j<nbFrames; j++) {
			p[j] = frames.get(j).pitch;
		}
		
		// noise
		n = new boolean[nbFrames];
		
		for (int j=0; j<nbFrames; j++) {
			n[j] = frames.get(j).noise;
		}
		
		// ampl
		ampl = new double[nbFrames];
		
		for (int j=0; j<nbFrames; j++) {
			if (frames.get(j).ampl == 0) {
				ampl[j] = 0;
			} else {
				ampl[j] = 0.10+frames.get(j).ampl/2000.0;
			}
		}
		
		// freq/bandwidth
		fm = new double[4][nbFrames];
		bw = new double[4][nbFrames];
		
		for (int f = 0; f < 4; f++) {
			for (int j = 0; j < nbFrames; j++) {
				fm[f][j] = frames.get(j).fm[f];
				bw[f][j] = frames.get(j).bw[f];
			}
		}
	}
}
