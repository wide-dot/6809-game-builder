package com.widedot.toolbox.debug.util;

import javax.sound.sampled.AudioFormat;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.SourceDataLine;

import com.widedot.toolbox.debug.ui.Mea8000Device;

import lombok.extern.slf4j.Slf4j;

public class SoundPlayerBlock {

	public final static int SAMPLE_RATE = 64000; // Hz
	public final static int BIT_DEPTH = 16;      // bits
	
	private AudioFormat af = new AudioFormat((float)SAMPLE_RATE, BIT_DEPTH, 1, true, false);	
	private SourceDataLine sdl;
	
	public void play (byte[] audioBuffer) {
	    try {		
			sdl = AudioSystem.getSourceDataLine(af);
			sdl.open();
		    sdl.start();
		    sdl.write(audioBuffer, 0, audioBuffer.length);
		    sdl.drain();
		    sdl.stop();
		    sdl.close();
		    
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

}