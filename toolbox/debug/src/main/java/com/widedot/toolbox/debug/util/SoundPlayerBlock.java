package com.widedot.toolbox.debug.util;

import javax.sound.sampled.AudioFormat;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.SourceDataLine;

public class SoundPlayerBlock {

	public final static int SAMPLE_RATE = 64000; // Hz
	public final static int BIT_DEPTH = 16;      // bits
	
	private AudioFormat af;
	private SourceDataLine sdl;
	
	public void play (byte[] audio_buffer) {
	    try {		
		    af = new AudioFormat((float)SAMPLE_RATE, BIT_DEPTH, 1, true, false);
			sdl = AudioSystem.getSourceDataLine(af);
			sdl.open();
		    sdl.start();
		    
		    sdl.write(audio_buffer, 0, audio_buffer.length);
			
			sdl.stop();
			sdl.flush();
		    
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

}