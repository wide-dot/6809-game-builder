package com.widedot.toolbox.debug.ui;

import java.util.Arrays;
import java.util.Random;

import javax.sound.sampled.AudioFormat;
import javax.sound.sampled.SourceDataLine;

import lombok.extern.slf4j.Slf4j;

//license:BSD-3-Clause
//copyright-holders:Antoine Mine
/**********************************************************************
 * 
 * Copyright (C) Antoine Mine' 2006
 * 
 * Philips / Signetics MEA 8000 emulation.
 * 
 * The MEA 8000 is a speech synthesis chip. The French company TMPI
 * (Techni-musique & parole informatique) provided speech extensions for several
 * 8-bit computers (Thomson, Amstrad, Oric). It was quite popular in France
 * because of its ability to spell 'u' (unlike the more widespread SPO 296
 * chip).
 * 
 * The synthesis is based on a 4-formant model. First, an initial sawtooth noise
 * signal is generated. The signal passes through a cascade of 4 filters of
 * increasing frequency. Each filter is a second order digital filter with a
 * programmable frequency and bandwidth. All parameters, including filter
 * parameters, are smoothly interpolated for the duration of a frame (8ms, 16ms,
 * 32ms, or 64 ms).
 * 
 * TODO: - REQ output pin - optimize mea8000_compute_sample - should we accept
 * new frames in slow-stop mode ?
 * 
 **********************************************************************/
@Slf4j
public class Mea8000Device {

	private static final int QUANT = 512;
	private static final int TABLE_LEN = 3600;
	private static final int NOISE_LEN = 8192;
	private static final int F0 = (3840000 / 480); // digital filters work at 8 kHz
	private static final int SUPERSAMPLING = 8; // filtered output is supersampled x 8
	private static final int[] fm1_table  = { 150, 162, 174, 188, 202, 217, 233, 250, 267, 286, 305, 325, 346, 368, 391, 415, 440, 466, 494, 523, 554, 587, 622, 659, 698, 740, 784, 830, 880, 932, 988, 1047 };
	private static final int[] fm2_table  = { 440, 466, 494, 523, 554, 587, 622, 659, 698, 740, 784, 830, 880, 932, 988, 1047, 1100, 1179, 1254, 1337, 1428, 1528, 1639, 1761, 1897, 2047, 2214, 2400, 2609, 2842, 3105, 3400 };
	private static final int[] fm3_table  = { 1179, 1337, 1528, 1761, 2047, 2400, 2842, 3400 };
	private static final int[] fm4_table  = { 3500 };
	private static final int[] bw_table   = { 726, 309, 125, 50 };
	private static final int[] ampl_table = { 0, 8, 11, 16, 22, 31, 44, 62, 88, 125, 177, 250, 354, 500, 707, 1000 };
	private static final int[] pi_table   = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0, -15, -14, -13, -12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1 };

	private enum Mea8000State {
		STOPPED, // nothing to do, timer disabled
		WAIT_FIRST, // received pitch, wait for first full frame, timer disabled
		STARTED, // playing a frame, timer on
		SLOWING // repeating last frame with decreasing amplitude, timer on
	}

	// Instance variables
	private static int m_output;
	private static Mea8000State m_state = Mea8000State.STOPPED; // current state
	private static byte[] m_buf = new byte[4]; // store 4 consecutive data to form a frame info
	private static int m_bufpos;               // new byte to write in frame info buffer
	private static int m_cont;                 // if no data 0=stop 1=repeat last frame
	private static int m_roe;                  // enable req output, now unimplemented
	private static int m_framelength;          // in samples
	private static int m_framepos;             // in samples
	private static int m_framelog;             // log2 of framelength
	private static int m_lastsample;           // output samples are interpolated
	private static int m_sample;               // output samples are interpolated
	private static int m_phi;                  // absolute phase for frequency / noise generator
	private static FType[] m_f = new FType[4]; // filters
	private static int m_last_ampl;            // amplitude * 1000
	private static int m_ampl;
	private static int m_last_pitch;           // pitch of sawtooth signal, in Hz
	private static int m_pitch;
	private static boolean m_noise = false;
	private static double[] m_cos_table = new double[TABLE_LEN];
	private static double[] m_exp_table = new double[TABLE_LEN];
	private static double[] m_exp2_table = new double[TABLE_LEN];
	private static int[] m_noise_table = new int[NOISE_LEN];
	private static Random random = new Random();
	
	// Audio
	private static int AUDIO_BUFFER_SIZE = 64*8*2; // audio buffer size for 8ms
    private static byte[] audio_buffer;
    private static AudioFormat af;
    private static SourceDataLine sdl;


	// FType class to hold filter parameters
	private static class FType {
		int fm;
		int last_fm;
		int bw;
		int last_bw;
		int output;
		int last_output;
	}

	// init filters
	public Mea8000Device() {
		for (int i = 0; i < m_f.length; i++) {
			m_f[i] = new FType();
		}
		
		for (int i = 0; i < TABLE_LEN; i++) {
			double f = (double) i / F0;
			m_cos_table[i] = 2.0 * Math.cos(2.0 * Math.PI * f) * QUANT;
			m_exp_table[i] = Math.exp(-Math.PI * f) * QUANT;
			m_exp2_table[i] = Math.exp(-2 * Math.PI * f) * QUANT;
		}
		
		for (int i = 0; i < m_noise_table.length; i++) {
			m_noise_table[i] = (random.nextInt(2 * (int) QUANT)) - (int) QUANT;
		}
	}
	
	public int read(long offset) {
		switch ((int) offset) {
		case 0:
		case 1:
			return (acceptByte() == true ? 1 : 0) << 7;

		default:
			log.error("mea8000_r invalid read offset {}", offset);
		}
		return 0;
	}

	public void write(long offset, byte data) {
		switch ((int) offset) {
		case 0:
			if (m_state == Mea8000State.STOPPED) {
				m_pitch = 2 * data;
				log.info("mea8000_w pitch {}Hz", m_pitch);
				m_state = Mea8000State.WAIT_FIRST;
				m_bufpos = 0;
			} else if (m_bufpos == 4) {
				log.info("mea8000_w data overflow ${}", String.format("%02x", data));
			} else {
				log.info("mea8000_w data ${} in frame pos {}", String.format("%02x", data), m_bufpos);
				m_buf[m_bufpos] = data;
				m_bufpos++;
				if (m_bufpos == 4 && m_state == Mea8000State.WAIT_FIRST) {
					int oldPitch = m_pitch;
					m_last_pitch = oldPitch;
					decodeFrame();
					shiftFrame();
					m_last_pitch = oldPitch;
					m_ampl = 0;
					startFrame();
					m_state = Mea8000State.STARTED;
				}
			}
			break;

		case 1:
			int stop = (data >> 4) & 1;

			if ((data & 8) != 0) {
				m_cont = (data >> 2) & 1;
			}

			if ((data & 2) != 0) {
				m_roe = (data & 1);
			}

			if (stop != 0) {
				stopFrame();
			}

			log.info("mea8000_w command {} stop={} cont={} roe={}", data, stop, m_cont, m_roe);
			break;

		default:
			log.error("mea8000_w invalid write offset {}", offset);
		}
	}

	private int computeSample() {
		int out;
		int ampl = interp(m_last_ampl, m_ampl);

		if (m_noise) {
			out = noiseGen();
		} else {
			out = freqGen();
		}

		out *= ampl / 32;

		for (int i = 0; i < 4; i++) {
			out = filterStep(i, out);
		}

		if (out > 32767) {
			out = 32767;
		}
		if (out < -32767) {
			out = -32767;
		}
		return out;
	}

	private void shiftFrame() {
		m_last_pitch = m_pitch;
		for (FType elem : m_f) {
			elem.last_bw = elem.bw;
			elem.last_fm = elem.fm;
		}
		m_last_ampl = m_ampl;
	}

	private void decodeFrame() {
		
		int fd = (m_buf[3] & 0xff >> 5) & 3; // 0=8ms, 1=16ms, 2=32ms, 3=64ms
		int pi = pi_table[m_buf[3] & 0x1f] << fd;
		m_noise = (m_buf[3] & 0x1f) == 16;
		m_pitch = m_last_pitch + pi;
		m_f[0].bw = bw_table[m_buf[0] & 0xff >> 6];
		m_f[1].bw = bw_table[(m_buf[0] & 0xff >> 4) & 3];
		m_f[2].bw = bw_table[(m_buf[0] & 0xff >> 2) & 3];
		m_f[3].bw = bw_table[m_buf[0] & 0xff & 3];
		m_f[3].fm = fm4_table[0];
		m_f[2].fm = fm3_table[m_buf[1] & 0xff >> 5];
		m_f[1].fm = fm2_table[m_buf[1] & 0x1f];
		m_f[0].fm = fm1_table[m_buf[2] & 0xff >> 3];
		m_ampl = ampl_table[((m_buf[2] & 0xff & 7) << 1) | (m_buf[3] & 0xff >> 7)];
		m_framelog = fd + 6 + 3; // 64 samples / ms
		m_framelength = 1 << m_framelog;
		m_bufpos = 0;

		log.info(
				"mea800_decode_frame: pitch={}Hz noise={}  fm1={}Hz bw1={}Hz  fm2={}Hz bw2={}Hz  fm3={}Hz bw3={}Hz  fm4={}Hz bw4={}Hz  ampl={} fd={}ms",
				m_pitch, m_noise, m_f[0].fm, m_f[0].bw, m_f[1].fm, m_f[1].bw, m_f[2].fm, m_f[2].bw, m_f[3].fm,
				m_f[3].bw, m_ampl / 1000.0, 8 << fd);
	}

	private void startFrame() {
		/* enter or stay in active mode */
		m_framepos = 0;
	}

	private void stopFrame() {
		/* enter stop mode */
		m_state = Mea8000State.STOPPED;
		m_output = 0;
	}
	
	public byte[] compute(byte[] data) {
		
		int i = 0;
		int j = 0;
		
		// first byte is a command
		if (data.length > 0) {
			write(1, data[i++]);
		}
		
		// second byte is pitch
		if (data.length > 0) {
			write(0, data[i++]);
		}
		
		// remaining bytes are data
		while(i+3 < data.length) {
			write(0, data[i++]);
			write(0, data[i++]);
			write(0, data[i++]);
			write(0, data[i++]);

			if (m_framepos > 0) {
				shiftFrame();
				decodeFrame();
				startFrame();
			}
			
			if (audio_buffer == null) {
				audio_buffer = new byte[m_framelength*2];
			} else {
				audio_buffer = Arrays.copyOf(audio_buffer, audio_buffer.length+m_framelength*2);
			}
			
			while(m_framepos < m_framelength) {
				int pos = m_framepos % SUPERSAMPLING;
		
				if (pos == 0) {
					m_lastsample = m_sample;
					m_sample = computeSample();
					m_output = m_lastsample;
				} else {
					m_output = m_lastsample + ((pos * (m_sample - m_lastsample)) / SUPERSAMPLING);
				}
		
				audio_buffer[j++] = (byte) (m_output & 0xFF);
				audio_buffer[j++] = (byte) (m_output >> 8);
				
				m_framepos++;
			}
		}
		
		return audio_buffer;
	}

	private boolean acceptByte() {
		return m_state == Mea8000State.STOPPED || m_state == Mea8000State.WAIT_FIRST
				|| (m_state == Mea8000State.STARTED && m_bufpos < 4);
	}

	private int interp(int org, int dst) {
		return org + (((dst - org) * m_framepos) >> m_framelog);
	}

	private int filterStep(int i, int input) {
		int fm = interp(m_f[i].last_fm, m_f[i].fm);
		int bw = interp(m_f[i].last_bw, m_f[i].bw);
		int b = (int) (m_cos_table[fm] * m_exp_table[bw] / QUANT);
		int c = (int) m_exp2_table[bw];
		int nextOutput = input + (b * m_f[i].output - c * m_f[i].last_output) / (int) QUANT;
		m_f[i].last_output = m_f[i].output;
		m_f[i].output = nextOutput;
		return nextOutput;
	}

	private int noiseGen() {
		m_phi = (m_phi + 1) % NOISE_LEN;
		return m_noise_table[m_phi];
	}

	private int freqGen() {
		int pitch = interp(m_last_pitch, m_pitch);
		m_phi = (m_phi + pitch) % (int) F0;
		return ((m_phi % (int) F0) * (int) QUANT * 2) / (int) F0 - (int) QUANT;
	}
	
}
