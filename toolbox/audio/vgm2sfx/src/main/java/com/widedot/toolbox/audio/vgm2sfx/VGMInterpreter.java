package com.widedot.toolbox.audio.vgm2sfx;

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
	public static final int _YMMAIN = 9;

	private VGMInputStream input;
	public int[] arrayOfInt = new int[0x80000];
	public int i = 0, s = 0;
	public int loopMarkerHit = 0;
	public int cumulatedFrames = 0, oldCumulatedFrames = -1;
	public int cumulatedSamples = 0;
	public int[] ymreg = new int[0x39];
	public boolean[] ymupd = new boolean[0x39];
	public int[][] stat = new int[256][256];
	public String asm = ""; 
	

	public VGMInterpreter(File paramFile) throws IOException {
		this.input = new VGMInputStream(paramFile);
		
		for (int j = 0; j < ymupd.length; j++) {
			ymupd[j] = false;
		}
		
		while(run());
		
		boolean debug = Boolean.getBoolean("logback.debug");
		
		if (debug) {
			log.debug("YM2413 STAT");
	        HashMap<String, Integer> map = new HashMap<>();
	        LinkedHashMap<String, Integer> sortedMap = new LinkedHashMap<>();
	        ArrayList<Integer> list = new ArrayList<>();
	        int redundancy = 0, distinct = 0;
	        
			for (int k=0; k < stat.length; k++) {
				for (int l=0; l < stat[0].length; l++) {
					if (stat[k][l]>32) {
						map.put(String.format("%02X%02X", k, l), stat[k][l]);
						redundancy += stat[k][l];
						distinct++;
					}
				}
			}
			
	        for (Map.Entry<String, Integer> entry : map.entrySet()) {
	            list.add(entry.getValue());
	        }
	        Collections.sort(list, Collections.reverseOrder());
	        for (int num : list) {
	            for (Entry<String, Integer> entry : map.entrySet()) {
	                if (entry.getValue().equals(num)) {
	                    sortedMap.put(entry.getKey(), num);
	                }
	            }
	        }
	        log.debug(sortedMap.toString());
	        log.debug("redundancy: {} distinct: {}", redundancy, distinct);
		}
		
		this.input.close();
	}

	public boolean run() throws IOException {		
		boolean endFrame = false;
		int waitTime = 0;
		int code = 0;
		
		while (!endFrame) {

			if (this.input.isLoopPoint()) {
				fireWriteDelay();
				fireLoopPointHit();
			}

			switch (code = this.input.read()) {
			case 0x4F: // Game Gear PSG stereo
				this.input.skip(1L);
				continue;
			case 0x50: // PSG (SN76489/SN76496) write value dd
				this.input.skip(1L);
				continue;
			case 0x51: // YM2413, write value dd to register aa
				int cmd = this.input.read();
				int data = this.input.read();
				fireWrite(cmd, data);
				continue;          				
			case 0x52: case 0x53: case 0x54: case 0x55: case 0x56: case 0x57: case 0x58: case 0x59: case 0x5A: case 0x5B: case 0x5C: case 0x5D: case 0x5E: case 0x5F:        	
				this.input.skip(2L); // write value dd to register aa
				continue;     
			case 0x61: // Wait n samples, n can range from 0 to 65535
				waitTime = this.input.readShort();
				cumulatedSamples += waitTime;
           		endFrame = true;
				continue;
			case 0x62: // wait 735 samples (60th of a second)
				cumulatedSamples += 735;
				endFrame = true;
				continue;
            case 0x63: // wait 882 samples (50th of a second)
            	cumulatedSamples += 882;
				endFrame = true;
				continue;
			case 0x66: // end of sound data
				fireWriteEnd();				
				return false;
			case 0x67: // data block
				continue;		
			case 0x70: case 0x71: case 0x72: case 0x73: case 0x74: case 0x75: case 0x76: case 0x77: case 0x78: case 0x79: case 0x7A: case 0x7B: case 0x7C: case 0x7D: case 0x7E: case 0x7F:
                // Wait n+1 samples, n can range from 0 to 15
				waitTime = (code & 0xf) + 1;
				cumulatedSamples += waitTime;
           		endFrame = true;
				continue;
			case 0x80: case 0x81: case 0x82: case 0x83: case 0x84: case 0x85: case 0x86: case 0x87: case 0x88: case 0x89: case 0x8A: case 0x8B: case 0x8C: case 0x8D: case 0x8E: case 0x8F:
                // YM2612 port 0 address 2A write from the data bank
				// then Wait n samples, n can range from 0 to 15
				this.input.skip(1L);
				waitTime = (code & 0xf);
				cumulatedSamples += waitTime;
           		endFrame = true;
				continue;
			case 0x90: // DAC Stream Control Write - Setup Stream Control
				this.input.skip(4L);
				continue;
			case 0x91: // DAC Stream Control Write - Set Stream Data
				this.input.skip(4L);
				continue;
			case 0x92: // DAC Stream Control Write - Set Stream Frequency
				this.input.skip(5L);
				continue;
			case 0x93: // DAC Stream Control Write - Start Stream
				this.input.skip(10L);
				continue;
			case 0x94: // DAC Stream Control Write - Stop Stream
				this.input.skip(1L);
				continue;
			case 0x95: // DAC Stream Control Write - Start Stream (fast call)
					this.input.skip(3L);
				continue;								
			case 0xE0:        	
				this.input.skip(4L); // data reg
				continue;               
			} 
			
			this.input.close();
			throw new IOException("Unknown VGM command encountered at x" + Integer.toHexString(this.input.getPosition() - 1) + ": x" + Integer.toHexString(code));
		}
		
		return true;
	}

	public int getTotalSamples() {
		return this.input.getTotalSamples();
	}

	public void fireLoopPointHit() {
		loopMarkerHit = s;
		
		// reinit cache at loop start
		for (int i=0; i < ymupd.length; i++) {
			ymupd[i] = false;
		}
		
		log.debug(String.format("            [LOOP POINT: %04X]", s));
	}

	public void fireWrite(int cmd, int data) {
		
		// filter data
		if (cmd >= 0x20 && cmd <= 0x28) {
			data = data & 0b00111111;
		}
		
		// skip redundant command
		if (ymupd[cmd] && ymreg[cmd] == data) {
			log.debug(String.format("%04X: %02X %02X [SKIP]", s, cmd, data));
			return;
		}
		
		fireWriteDelay();
		
		arrayOfInt[s++] = cmd;
		arrayOfInt[s++] = data;
		ymreg[cmd] = data;
		ymupd[cmd] = true;
		log.debug(String.format("%04X: %02X %02X", s-2, cmd, data));
		stat[cmd][data] = stat[cmd][data]+1;
		
		// filter command
		if (cmd >= 0x10 && cmd <= 0x38) {
			int channel = cmd >> 4;
			cmd = cmd & 0b11110000;
		}
		
		asm += String.format("        fcb     $%02X,$%02X,", cmd, data);
	}
	
	public void fireWriteDelay() {
		int offset = 0x39;
		String asmDelay = "0\n";
    	cumulatedFrames += cumulatedSamples/SAMPLES_PER_FRAME_PAL;
    	cumulatedSamples = cumulatedSamples%SAMPLES_PER_FRAME_PAL; // saves remaining value
		
		while (cumulatedFrames > 0) {
			if (cumulatedFrames > 198) {
				arrayOfInt[s++] = offset+cumulatedFrames;
				cumulatedFrames -= 198;
			} else {
				arrayOfInt[s++] = offset+cumulatedFrames;
				cumulatedFrames = 0;
			}
			log.debug(String.format("%04X: %02X    [WAIT: %d frame(s)]", s-1, arrayOfInt[s-1], arrayOfInt[s-1]-offset));
			asmDelay = String.format("%d\n\n", arrayOfInt[s-1]-offset);
		}
		
		asm += asmDelay;
	}
	
	public void fireWriteEnd() {
		fireWriteDelay();
		arrayOfInt[s++] = 0x39;
	}
	
	public int[] getArrayOfInt() {
		return arrayOfInt;
	}
	
	public byte[] getBytes() {
		if (asm == null) {
			return new byte[0];
		}
		byte[] bytes = new byte[asm.length()];
		for (int i = 0; i < asm.length(); i++) {
			bytes[i] = (byte) asm.charAt(i);
		}
		return bytes;
	}
	
	public int getLastIndex() {
		return s;
	}	
}
