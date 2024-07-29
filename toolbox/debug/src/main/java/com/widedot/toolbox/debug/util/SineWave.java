package com.widedot.toolbox.debug.util;

public class SineWave {

	protected static final int SAMPLE_RATE = 64000;
	
	public static byte[] createSinWaveBuffer(double freq, int ms) {
		int samples = (int) ((2 * ms * SAMPLE_RATE) / 1000);
		byte[] output = new byte[samples];

		double period = (double) SAMPLE_RATE / freq;
		for (int i = 0; i < output.length; i+=2) {
			double angle = Math.PI * i / period;
			output[i] = (byte) ((int)(Math.sin(angle) * 32767f) & 0xFF);
			output[i+1] = (byte) ((int)(Math.sin(angle) * 32767f) >> 8);
		}
		return output;
	}

}