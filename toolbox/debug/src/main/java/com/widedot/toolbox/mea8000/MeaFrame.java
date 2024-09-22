package com.widedot.toolbox.mea8000;

import java.util.Arrays;

public class MeaFrame {
	
		int     fd;
		int     phi;
		int     pitch;
		int[]   output;
		int[]   last_output;
		int     sample;
		boolean newPitch;
		boolean noise;
		
		int     ampl;
		int[]   fm;
		int[]   bw;

		int     i_pi;
		int     i_ampl;
		int[]   i_fm;
		int[]   i_bw;
		
		int     i_bckampl;
		
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
			this.i_ampl = src.i_ampl;
			this.ampl = src.ampl;
			this.i_pi = src.i_pi;
			
			copyFilters(src);
		}
		
		public void copyFilters(MeaFrame src) {
			this.i_fm = Arrays.copyOf(src.i_fm, src.i_fm.length);
			this.i_bw = Arrays.copyOf(src.i_bw, src.i_bw.length);
			this.fm = Arrays.copyOf(src.fm, src.fm.length);
			this.bw = Arrays.copyOf(src.bw, src.bw.length);
		}
	}