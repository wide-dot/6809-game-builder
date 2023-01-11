package com.widedot.toolbox.audio.svgm;

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
	public static final int _SN76489 = 0;
	public static final int _YM2413 = 1;
	public static final int _ALL = -1;
	public static final int _YMMAIN = 9;

	private VGMInputStream input;
	public int[] arrayOfInt = new int[0x80000];
	public int i = 0, s = 0;
	public int loopMarkerHit = 0;
	public int cumulatedFrames = 0, oldCumulatedFrames = -1;
	public int[] drum;
	public int[] drumAtt;
	public int chip;
	public int channel;
	public int currentChannel = -1;
	public int currentDrums = 0;
	public int[] ymreg = new int[0x39];
	public boolean[] ymupd = new boolean[0x39];
	public int[][] stat = new int[256][256];
	

	public VGMInterpreter(File paramFile, int[] drumAtt, int[] drum, int chip, int channel) throws IOException {
		this.input = new VGMInputStream(paramFile);
		this.drumAtt = drumAtt;
		this.drum = drum;
		this.chip = chip;
		this.channel = channel;
		
		for (int j = 0; j < ymupd.length; j++) {
			ymupd[j] = false;
		}
		
		while(run()) {
		}
		
		// print YM2413 stats
		if (chip==-1 || chip == _YM2413) {
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
	        log.debug("redundancy: "+redundancy+" distinct:"+distinct);
		}
	}

	public boolean run() throws IOException {		
		boolean skipFrame = false;
		while (!skipFrame) {
			
			if (this.input.isLoopPoint())
				fireLoopPointHit(); 
			int i = this.input.read();

			switch (i) {
			case 0x4F: // Game Gear PSG stereo
				this.input.skip(1L);
				continue;
			case 0x50: // PSG (SN76489/SN76496) write value dd
				
				// %1cct xxxx = Latch/Data byte for SN76489 channel c, type t (1:volume or 0:tone/noise) , data xxxx (4 bits)
				// %01xx xxxx = Data byte for SN76489 latched channel and type, data xxxxxx (6 bits)
				
				if (chip==-1 || chip == _SN76489) {
					int val = this.input.read();
					if (val <= 127 ) {
						val = val | 0b01000000;
						if (currentChannel == channel || channel==_ALL)
							fireWrite(val);
					} else {
						currentChannel = (val & 0b01100000) >> 5;
						if (currentChannel == channel || channel==_ALL)
							fireWrite(val);
					}
				} else {
					this.input.skip(1L);
				}
				continue;
			case 0x51: // YM2413, write value dd to register aa
				if (chip==-1 || chip == _YM2413) {
					
					int cmd = this.input.read();
					int data = this.input.read();
					
					if (cmd < 16) {
						currentChannel = _YMMAIN;
					} else {
						currentChannel = cmd & 0xf;
					}
					
					if (drumAtt != null) {
						// Overwrite drum volume
						if (cmd==0x36)
							data = drumAtt[0];
						if (cmd==0x37)
							data = drumAtt[1];
						if (cmd==0x38)
							data = drumAtt[2];
					}
					
					if (currentChannel == channel || channel==_ALL) {
						fireWrite(cmd, data);
					}
				} else {
					this.input.skip(2L);
				}
				
				continue;          				
			case 0x52: case 0x53: case 0x54: case 0x55: case 0x56: case 0x57: case 0x58: case 0x59: case 0x5A: case 0x5B: case 0x5C: case 0x5D: case 0x5E: case 0x5F:        	
				this.input.skip(2L); // write value dd to register aa
				continue;          								
			case 0x61: // Wait n samples, n can range from 0 to 65535
				int waitTime = this.input.readShort();
				if (waitTime%SAMPLES_PER_FRAME_PAL != 0) {
					close();
					throw new IOException("0x61 VGM command not supported at " + Integer.toHexString(this.input.getPosition() - 3) + ": " + Integer.toHexString(waitTime) + "\n");
				}
            	cumulatedFrames += waitTime/SAMPLES_PER_FRAME_PAL;				
				skipFrame = true;
				continue;
			case 0x62: // wait 735 samples (60th of a second)
				//close();
				//throw new IOException("0x62 VGM command not supported at " + Integer.toHexString(this.input.getPosition() - 3) + "\nOnly PAL wait frame is supported either 0x61 0x72 0x03 or 0x63 command");
            	cumulatedFrames++;
				skipFrame = true;
				continue;
            case 0x63: // wait 882 samples (50th of a second)
            	cumulatedFrames++;
				skipFrame = true;
				continue;
			case 0x66: // end of sound data
				fireWriteEnd();				
				close();
				return false;
			case 0x67: // data block
				continue;				
			case 0x80: case 0x81: case 0x82: case 0x83: case 0x84: case 0x85: case 0x86: case 0x87: case 0x88: case 0x89: case 0x8A: case 0x8B: case 0x8C: case 0x8D: case 0x8E: case 0x8F:
				this.input.skip(1L);
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
				if (((chip==-1 || chip == _YM2413) && drum != null) && (channel == _YMMAIN || channel==_ALL)) {
					
					fireWrite(0x0E);
					fireWrite(0x20);
					fireWrite(0x0E);
					this.input.read();      // Stream id
					int blockId = this.input.readShort(); // Block id
					fireWrite(drum[blockId%drum.length]);
					this.input.skip(1L);    // skip Flags
				} else {
					this.input.skip(3L);
				}
				continue;								
			case 0xE0:        	
				this.input.skip(4L); // data reg
				continue;               
			} 
			close();
			throw new IOException("Unknown VGM command encountered at " + Integer.toHexString(this.input.getPosition() - 1) + ": " + Integer.toHexString(i));
		} 

		return true;
	}

	public int getTotalSamples() {
		return this.input.getTotalSamples();
	}

	public void close() throws IOException {
		this.input.close();
	}

	public void fireLoopPointHit() {
		loopMarkerHit = s;
	}
	
	public void fireWrite(int paramInt) {
		fireWriteDelay();
		arrayOfInt[s++] = paramInt;
		log.debug(String.format("[SN76489] %02X", arrayOfInt[s-1]));
	}
	
	public void fireWrite(int cmd, int data) {
		if (ymupd[cmd] && ymreg[cmd] == data) {
			log.debug(String.format("[YM2413] %02X %02X >>> SKIPPED", cmd, data));
			return;
		}
		fireWriteDelay();
		arrayOfInt[s++] = cmd;
		arrayOfInt[s++] = data;
		ymreg[cmd] = data;
		ymupd[cmd] = true;
		log.debug(String.format("[YM2413] %02X %02X", cmd, data));
		stat[cmd][data] = stat[cmd][data]+1; 
	}
	
	public void fireWriteDelay() {
		int offset = 0x39;
		while (cumulatedFrames > 0) {
			if (chip == _YM2413) {
				if (cumulatedFrames > 198) {
					arrayOfInt[s++] = offset+cumulatedFrames;
					cumulatedFrames -= 198;
				} else {
					arrayOfInt[s++] = offset+cumulatedFrames;
					cumulatedFrames = 0;
				}
				log.debug(String.format("[WAIT] %02X (%d)", arrayOfInt[s-1], arrayOfInt[s-1]-offset));
			} else {
				arrayOfInt[s++] = 0x39;
				if (cumulatedFrames > 127) {
					arrayOfInt[s++] = cumulatedFrames;
					cumulatedFrames -= 127;
				} else {
					arrayOfInt[s++] = cumulatedFrames;
					cumulatedFrames = 0;
				}
				log.debug(String.format("[WAIT] \n%02X (%d)", arrayOfInt[s-1], arrayOfInt[s-1]));
			}
		}
	}
	
	public void fireWriteEnd() {
		fireWriteDelay();
		arrayOfInt[s++] = 0x39;
		if (!(chip == _YM2413)) {
			arrayOfInt[s++] = 0x00;
		}
	}
	
	public int[] getArrayOfInt() {
		return arrayOfInt;
	}
	
	public int getLastIndex() {
		return s;
	}	
}
