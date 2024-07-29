package com.widedot.toolbox.debug.util;

import java.util.Timer;
import java.util.TimerTask;

public class SoundPlayer {

	private Timer timer;
	private TimerTask tt;
	
	public void play(byte[] buf) {
		
		if (tt != null) {
			tt.cancel();
		}

		timer = new Timer();
		tt = new SoundPlayerTask(buf);
		timer.scheduleAtFixedRate(tt, 0, SoundPlayerTask.SAMPLE_DURATION);
	}

}