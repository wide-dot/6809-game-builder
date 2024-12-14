package com.widedot.toolbox.mea8000;


import java.io.ByteArrayInputStream;
import java.util.concurrent.CountDownLatch;

import javax.sound.sampled.AudioFormat;
import javax.sound.sampled.AudioInputStream;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.Clip;
import javax.sound.sampled.LineEvent;

public class AudioPlayer {
	
	public static final int SAMPLE_SIZE_IN_BYTES = 2;
	public static final int SAMPLE_SIZE_IN_BITS = SAMPLE_SIZE_IN_BYTES*8;
	public static final int SAMPLE_RATE = 64000;

	public static void playAudio(float[] audio) {
		byte[] audioOut = new byte[audio.length*SAMPLE_SIZE_IN_BYTES];
		
		int j = 0;
		for (int i=0; i<audio.length; i++) {
			audioOut[j++] = (byte) ((int)audio[i] >> 8);
			audioOut[j++] = (byte) ((int)audio[i] & 0xff);
		}
		
		playAudio(audioOut);
	}
	
	public static void playAudio(byte[] audio) {
		AudioInputStream audioIS = new AudioInputStream(
		        new ByteArrayInputStream(audio), 
		        new AudioFormat(SAMPLE_RATE, SAMPLE_SIZE_IN_BITS, 1, true, true),
		        audio.length/2);
		
        CountDownLatch syncLatch = new CountDownLatch(1);
		try {
			Clip clip = AudioSystem.getClip();
			// Listener which allow method return once sound is completed
			clip.addLineListener(e -> {
				if (e.getType() == LineEvent.Type.STOP) {
					syncLatch.countDown();
				}
			});
			clip.open(audioIS);
			clip.start();
			syncLatch.await();
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}