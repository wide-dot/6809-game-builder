package com.widedot.toolbox.mea8000;

import java.util.Arrays;

public class MeaFrame {
	    public int     pos;
	    public int     phi;         // phase increment
	    public int[]   output;      // wave data
	    
	    public int     fd;          // frame duration (0=8ms, 1=16ms, 2=32ms, 3=64ms) 
	    public int     pitch;       // pitch value (in Hz)
	    public boolean noise;       // flag if noise is used instead of pitch for this frame
	    public int     ampl;        // amplitude
	    public int[]   fm;          // 4x frequencies
	    public int[]   bw;          // 4x bandwidths

	    public int     i_pi;        // index for pitch increment
	    public int     i_ampl;      // index for amplitude
	    public int[]   i_fm;        // index for the 4x frequencies
	    public int[]   i_bw;        // index for the 4x bandwidths
		
		public MeaFrame () {
			output = new int[4];
			fm = new int[4];
			bw = new int[4];
			i_fm = new int[4];
			i_bw = new int[4];
		}
		
		public MeaFrame(MeaFrame src) {
			this.fd = src.fd;
			this.phi = src.phi;
			this.pitch = src.pitch;
			this.output = Arrays.copyOf(src.output, src.output.length);
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