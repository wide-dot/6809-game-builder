package com.widedot.toolbox.mea8000;


import java.io.File;

import javax.sound.sampled.AudioFormat;
import javax.sound.sampled.AudioInputStream;
import javax.sound.sampled.AudioSystem;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class AudioLoader {

	// audio Loader that match MEA8000 samplerate
	
	public static final int SAMPLE_SIZE_IN_BYTES = 2;
	public static final int SAMPLE_SIZE_IN_BITS = SAMPLE_SIZE_IN_BYTES*8;
	public static final int SAMPLE_RATE = 64000;
	public static final int CHANNELS = 1;
	public static final boolean SIGNED = true;
	public static final boolean BIG_ENDIAN = true;

	private AudioLoader() {};
	
	public static byte[] load(String pathName) {
		
		byte[] audio = null;
		
		try {
			
			log.debug("Load audo file: {}", pathName);
			
			final AudioFormat audioFormat = new AudioFormat(SAMPLE_RATE, SAMPLE_SIZE_IN_BITS, CHANNELS, SIGNED, BIG_ENDIAN);
			
			AudioInputStream ais = AudioSystem.getAudioInputStream(new File(pathName));
		    ais = AudioSystem.getAudioInputStream(audioFormat, ais);
		    audio = ais.readAllBytes();
		    
		    log.debug("Nb of samples: {}", audio.length/SAMPLE_SIZE_IN_BYTES);
		    
		} catch (Exception e) {
			
			log.error("Error loading file: {}", pathName);
			e.printStackTrace();
			
		}
		
		return audio;
	}
	
	public static float[] loadf(String pathName) {

		byte[] audio = load(pathName);
		float[] audiof = new float[audio.length/2];
		int j = 0;
		for (int i = 0; i < audio.length; i += SAMPLE_SIZE_IN_BYTES) {
			audiof[j] = (audio[i] << 8) | (audio[i+1] & 0xff);
			j++;
		}
		
		return audiof;
	}
}
