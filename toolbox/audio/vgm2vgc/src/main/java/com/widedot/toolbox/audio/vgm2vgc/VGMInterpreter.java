package com.widedot.toolbox.audio.vgm2vgc;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Map.Entry;

import lombok.extern.slf4j.Slf4j;
@Slf4j
public class VGMInterpreter {
	public static final int SAMPLES_PER_SECOND = 44100;
	public static final int SAMPLES_PER_FRAME_NTSC = 735;
	public static final int SAMPLES_PER_FRAME_PAL = 882;
	
	public static final int END_MARKER = 0x66;

	private VGMInputStream input;
	public byte[] data = new byte[0x80000];
	public int pos = 0;
	public int loopMarkerHit = 0, totalLoopMarkerFrames = 0;
	public int totalFrames = 1, oldCumulatedFrames = -1;
	public int curWaitSamples = 0;
	private byte[] header;
	

	public VGMInterpreter(File paramFile) throws IOException {
		this.input = new VGMInputStream(paramFile);
		while(run());	
		this.input.close();
	}

	public boolean run() throws IOException {		
		boolean endFrame = false;
		int waitTime = 0;
		
		while (!endFrame) {

			if (this.input.isLoopPoint()) {
				fireWriteDelay();
				fireLoopPointHit();
			}

			byte cmd = input.readByte();
			switch (cmd) {
			case 0x4F: // Game Gear PSG stereo
				this.input.skip(1L);
				continue;
			case 0x50: // PSG (SN76489/SN76496) write value dd
				fireWrite(cmd, input.readByte());
				continue;
			case 0x51: // YM2413, write value dd to register aa
				this.input.skip(2L);
				continue;          				
			case 0x52: case 0x53: case 0x54: case 0x55: case 0x56: case 0x57: case 0x58: case 0x59: case 0x5A: case 0x5B: case 0x5C: case 0x5D: case 0x5E: case 0x5F: // write value dd to register aa	
				this.input.skip(2L);
				continue;     
			case 0x61: // Wait n samples, n can range from 0 to 65535
				waitTime = this.input.readShort();
				curWaitSamples += waitTime;
           		endFrame = true;
				continue;
			case 0x62: // wait 735 samples (60th of a second)
				curWaitSamples += 735;
				endFrame = true;
				continue;
            case 0x63: // wait 882 samples (50th of a second)
            	curWaitSamples += 882;
				endFrame = true;
				continue;
			case END_MARKER: // end of sound data
				fireWriteDelay();
				data[pos++] = (byte) (cmd & 0xff) ;				
				return false;
			case 0x67: // data block
				continue;				
			case (byte) 0x80: case (byte) 0x81: case (byte) 0x82: case (byte) 0x83:
			case (byte) 0x84: case (byte) 0x85: case (byte) 0x86: case (byte) 0x87:
			case (byte) 0x88: case (byte) 0x89: case (byte) 0x8A: case (byte) 0x8B:
			case (byte) 0x8C: case (byte) 0x8D: case (byte) 0x8E: case (byte) 0x8F:
				this.input.skip(1L);
				continue;
			case (byte) 0x90: // DAC Stream Control Write - Setup Stream Control
				this.input.skip(4L);
				continue;
			case (byte) 0x91: // DAC Stream Control Write - Set Stream Data
				this.input.skip(4L);
				continue;
			case (byte) 0x92: // DAC Stream Control Write - Set Stream Frequency
				this.input.skip(5L);
				continue;
			case (byte) 0x93: // DAC Stream Control Write - Start Stream
				this.input.skip(10L);
				continue;
			case (byte) 0x94: // DAC Stream Control Write - Stop Stream
				this.input.skip(1L);
				continue;
			case (byte) 0x95: // DAC Stream Control Write - Start Stream (fast call)
				this.input.skip(3L);
				continue;								
			case (byte) 0xE0:        	
				this.input.skip(4L); // data reg
				continue;               
			} 
			
			this.input.close();
			throw new IOException("Unknown VGM command encountered at " + Integer.toHexString(input.getPosition() - 1) + ": " + Integer.toHexString(cmd));
		}
		
		return true;
	}

	public int getTotalSamples() {
		return totalFrames*SAMPLES_PER_FRAME_PAL;
	}

	public int getTotalLoopMarkerSamples() {
		return totalLoopMarkerFrames*SAMPLES_PER_FRAME_PAL;
	}
	
	public void fireLoopPointHit() {
		loopMarkerHit = pos;
		totalLoopMarkerFrames = totalFrames;
		log.debug(String.format("            [LOOP POINT: %04X]", pos));
	}

	public void fireWrite(byte cmd, byte val) {
		
		fireWriteDelay();
		data[pos++] = cmd;
		data[pos++] = val;
		
		log.debug(String.format("%04X: %02X %02X", pos-2, cmd, val));
	}
	
	public void fireWriteDelay() {
		int frames = curWaitSamples/SAMPLES_PER_FRAME_PAL;
    	curWaitSamples = curWaitSamples%SAMPLES_PER_FRAME_PAL; // saves remaining value
    	totalFrames += frames;
		
		while (frames > 0) {
			data[pos++] = 0x63;
			frames--;
			log.debug(String.format("%04X: %02X    [WAIT]", pos-1, data[pos-1]));
		}
	}
	
	public int getLastIndex() {
		return pos;
	}	
	
	public byte[] getIntroHeader() {
		return getHeader(loopMarkerHit+1, getTotalLoopMarkerSamples());
	}
	
	public byte[] getLoopHeader() {
		return getHeader(getLastIndex()-loopMarkerHit, getTotalSamples());
	}
	
	public byte[] getHeader(int size, int samples) {
		header = new byte[input.getHeaderSize()];
		header[0]  = 'V';
		header[1]  = 'g';
		header[2]  = 'm';
		header[3]  = ' ';
		setInt(header,  4, input.getHeaderSize()-4+size);
		setInt(header,  8, input.getVersion());
		setInt(header, 12, input.getPsgClock());
		
		setInt(header, 16, 0x00000000);               // YM2413 clock off
		setInt(header, 20, 0x00000000);               // GD3 offset (GD3 is stripped)
		setInt(header, 24, samples);                  // Total # samples
		setInt(header, 28, 0x00000000);               // loop offset (no loop, intro and loop are splitted in two files)
		
		setInt(header, 32, 0x00000000);               // loop # samples
		setInt(header, 36, 0x00000032);               // rate if forced to 50hz (required for vgmPacker)
		setInt(header, 40, input.getPsgConf());       // settings for SN76489 chip type
		setInt(header, 44, 0x00000000);               // YM2612 clock off
		
		setInt(header, 48, 0x00000000);               // YM2151 clock off
		setInt(header, 52, input.getVgmDataOffset()); // VGM data offset
		setInt(header, 56, 0x00000000);               // Sega PCM clock
		setInt(header, 60, 0x00000000);               // SPCM Interface

		return header;
	}
	
	public byte[] getIntroData() {
		byte[] intro = null;
		if (loopMarkerHit > 0) {
			
			intro = new byte[loopMarkerHit+1];
			int i = 0;
			for (i = 0; i < loopMarkerHit; i++) {
				intro[i] = data[i];
			}
			intro[i] = (byte) (END_MARKER & 0xff);
		}

		return intro;
	}
	
	public byte[] getLoopData() {
		byte[] loop = null;
		if (getLastIndex()-loopMarkerHit > 0) {
			
			loop = new byte[getLastIndex()-loopMarkerHit];
			int j = 0;
			for (int i = loopMarkerHit; i < getLastIndex(); i++) {
				loop[j++] = data[i];
			}
		}

		return loop;
	}
	
	private void setInt(byte[] data, int pos, int val) {
		data[pos]   = (byte) (val & 0xff);
		data[pos+1] = (byte) ((val >>  8) & 0xff);
		data[pos+2] = (byte) ((val >> 16) & 0xff);
		data[pos+3] = (byte) ((val >> 24) & 0xff);
	}
}
