package com.widedot.toolbox.debug.util;

import javax.sound.sampled.AudioFormat;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.SourceDataLine;

import lombok.extern.slf4j.Slf4j;

public class SoundPlayerBlock {

	private AudioFormat af;	
	private SourceDataLine sdl;
	
	public void play (byte[] audioBuffer, int sampleRate, int bitDepth) {
	    try {		
	    	af = new AudioFormat((float)sampleRate, bitDepth, 1, true, false);
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