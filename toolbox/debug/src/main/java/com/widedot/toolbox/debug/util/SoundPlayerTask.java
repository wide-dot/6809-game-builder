package com.widedot.toolbox.debug.util;

import java.util.Arrays;
import java.util.TimerTask;

import javax.sound.sampled.AudioFormat;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.SourceDataLine;

public class SoundPlayerTask extends TimerTask {

	public final static int SAMPLE_RATE = 64000; // Hz
	public final static int BIT_DEPTH = 16;      // bits
	public final static int SAMPLE_DURATION = 8; // ms
	public final static int AUDIO_BUFFER_SIZE = (SAMPLE_RATE/1000)*(BIT_DEPTH/8)*SAMPLE_DURATION; // audio buffer size for 8ms in 2 bytes (16bit)
	
	private AudioFormat af;
	private SourceDataLine sdl;
	private byte[] audio_buffer;
	private int pos;
	
	public SoundPlayerTask(byte[] buf) {
	    try {		
		    af = new AudioFormat((float)SAMPLE_RATE, BIT_DEPTH, 1, true, false);
			sdl = AudioSystem.getSourceDataLine(af);
			sdl.open();
		    sdl.start();
		    
			if (buf.length%AUDIO_BUFFER_SIZE == 0) {
				audio_buffer = buf;
			} else {
				audio_buffer = Arrays.copyOf(buf, ((buf.length/AUDIO_BUFFER_SIZE)+1)*AUDIO_BUFFER_SIZE);
			}
			
			pos = 0;
		    
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
	
	@Override
	public void run() {
		if (audio_buffer != null) {
			if (pos < audio_buffer.length/AUDIO_BUFFER_SIZE) {
				sdl.write (audio_buffer, pos*AUDIO_BUFFER_SIZE, AUDIO_BUFFER_SIZE);
				pos++;
			} else {
				sdl.stop();
				sdl.flush();
				audio_buffer = null;
		        this.cancel();
			}
		}
	}
	
}