package com.widedot.toolbox.mea8000;

public class Mea8000Decoder {
	
	public static final int[]   FM1_TABLE   = { 150, 162, 174, 188, 202, 217, 233, 250, 267, 286, 305, 325, 346, 368, 391, 415, 440, 466, 494, 523, 554, 587, 622, 659, 698, 740, 784, 830, 880, 932, 988, 1047 };
	public static final int[]   FM2_TABLE   = { 440, 466, 494, 523, 554, 587, 622, 659, 698, 740, 784, 830, 880, 932, 988, 1047, 1100, 1179, 1254, 1337, 1428, 1528, 1639, 1761, 1897, 2047, 2214, 2400, 2609, 2842, 3105, 3400 };
	public static final int[]   FM3_TABLE   = { 1179, 1337, 1528, 1761, 2047, 2400, 2842, 3400 };
	public static final int[]   FM4_TABLE   = { 3500 };
	public static final int[]   BW_TABLE    = { 726, 309, 125, 50 };
	public static final int[]   AMPL_TABLE  = { 0, 8, 11, 16, 22, 31, 44, 62, 88, 125, 177, 250, 354, 500, 707, 1000 };
	public static final int[]   PI_TABLE    = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0, -15, -14, -13, -12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1 };
	 
//    public int     i_pi;        // index for pitch increment
	
	public static MeaFrame decodeFrame(byte[] data, int pos, int pitch) {
		
		MeaFrame frame = new MeaFrame();
		
		frame.pos = pos;
		frame.fd = (data[pos+3] >> 5) & 3;
		frame.i_pi = PI_TABLE[data[pos+3] & 0x1f];
		frame.pitch = pitch + (frame.i_pi << frame.fd);
		frame.noise = (data[pos+3] & 0x1f) == 16;
		
		frame.i_bw[0] = (data[pos] & 0xff) >> 6;
		frame.i_bw[1] = (data[pos] >> 4) & 3;
		frame.i_bw[2] = (data[pos] >> 2) & 3;
		frame.i_bw[3] = data[pos] & 3;
		frame.bw[0] = BW_TABLE[frame.i_bw[0]];
		frame.bw[1] = BW_TABLE[frame.i_bw[1]];
		frame.bw[2] = BW_TABLE[frame.i_bw[2]];
		frame.bw[3] = BW_TABLE[frame.i_bw[3]];
		
		frame.i_fm[0] = (data[pos+2] & 0xff) >> 3;
		frame.i_fm[1] = data[pos+1] & 0x1f;
		frame.i_fm[2] = (data[pos+1] & 0xff) >> 5;
		frame.i_fm[3] = 0;
		frame.fm[0] = FM1_TABLE[frame.i_fm[0]];
		frame.fm[1] = FM2_TABLE[frame.i_fm[1]];
		frame.fm[2] = FM3_TABLE[frame.i_fm[2]];
		frame.fm[3] = FM4_TABLE[frame.i_fm[3]];
		
		frame.i_ampl = ((data[pos+2] & 7) << 1) | ((data[pos+3] & 0xff) >> 7);
		frame.ampl = AMPL_TABLE[frame.i_ampl];
		
//	    set phi         // phase increment
//	    set output      // wave data
		
		return frame;
	}
}