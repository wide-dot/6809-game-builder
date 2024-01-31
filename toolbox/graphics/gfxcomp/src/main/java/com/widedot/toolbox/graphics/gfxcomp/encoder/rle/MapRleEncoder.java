package com.widedot.toolbox.graphics.gfxcomp.encoder.rle;

import java.io.File;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.util.ArrayList;
import java.util.List;

import com.widedot.m6809.util.asm.AsmSourceCode;
import com.widedot.toolbox.graphics.gfxcomp.Image;
import com.widedot.toolbox.graphics.gfxcomp.encoder.Encoder;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class MapRleEncoder extends Encoder{

	boolean FORWARD = true;
	boolean REARWARD = false;
	public String name;
	public boolean spriteCenterEven;
	
	private int x_offset;
	private int x1_offset;
	private int y1_offset;
	private int x_size;
	private int y_size;
	private boolean isPlane0Empty;
	private boolean isPlane1Empty;
	
	// Code
	private List<String> spriteCode1 = new ArrayList<String>();
	private List<String> spriteCode2 = new ArrayList<String>();
	
	// Binary
	private String asmDrawFileName;
	private Path asmDFile;
	
	public MapRleEncoder(Image img, String destDir) throws Exception {
		spriteCenterEven = (img.getCoordinate() % 2) == 0;
		name = img.getFullName();
		x1_offset = img.getSubImageX1Offset();
		y1_offset = img.getSubImageY1Offset();
		x_size = img.getSubImageXSize();
		y_size = img.getSubImageYSize();
		isPlane0Empty = img.isPlane0Empty();
		isPlane1Empty = img.isPlane1Empty();		

		log.debug("\t\t\tImage:"+name);
		log.debug("\t\t\tXOffset: "+getX_offset());;
		log.debug("\t\t\tX1Offset: "+getX1_offset());
		log.debug("\t\t\tY1Offset: "+getY1_offset());
		log.debug("\t\t\tXSize: "+getX_size());
		log.debug("\t\t\tYSize: "+getY_size());	
		log.debug("\t\t\tCenter: "+img.getCoordinate());
		
		destDir += "/"+name;
		asmDrawFileName = destDir+".asm";
		File file = new File (asmDrawFileName);
		file.getParentFile().mkdirs();	
		asmDFile = Paths.get(asmDrawFileName);

		// Si l'option d'utilisation du cache est activée et qu'on trouve les fichiers .bin et .asm
		// on passe la génération des données
		if (!(Files.exists(asmDFile))) {

			//log.debug("RAM 0 (val hex 0 à f par pixel, . Transparent):");
			//if (log.isDebugEnabled())
				//log.debug(debug80Col(img.getSubImagePixels(imageNum, 0)));
			
			if (!isPlane0Empty)
				spriteCode1	= encode(img.getSubImagePixels(0), img.getCoordinate());

			//log.debug("\t\t\tRAM 1 (val hex 0  à f par pixel, . Transparent):");
			//if (log.isDebugEnabled())
				//log.debug(debug80Col(img.getSubImagePixels(imageNum, 1)));

			if (!isPlane0Empty)
				spriteCode2	= encode(img.getSubImagePixels(1), img.getCoordinate());
			
		}
	}
	
	public List<String> encode(byte[] dataIn, int center) throws Exception {

		byte[] data = new byte[dataIn.length / 2];
		byte[] alpha = new byte[dataIn.length / 2];
		int i_start = 0, i_end = data.length;
		boolean startFlag = true;

		for (int i = 0; i < data.length; i++) {
			
			data[i] = (byte) ((dataIn[i*2]==0?0:(((dataIn[i*2] & 0xff) - 1) << 4)) + (dataIn[1+i*2]==0?0:(dataIn[1+i*2] & 0xff) - 1));
            alpha[i] = (byte) (((dataIn[i*2]==0?0:1) << 4) + (dataIn[1+i*2]==0?0:1));
			
			if (alpha[i] == 0 && startFlag) {
				i_start = i;
			}

			if (alpha[i] != 0) {
				i_end = i;
				startFlag = false;
			}
		}
		i_end++;

		byte[] dataTrim = new byte[i_end-i_start];
		byte[] alphaTrim = new byte[i_end-i_start];
		
		for (int i = 0; i < dataTrim.length; i++) {
			dataTrim[i] = data[i+i_start];
			alphaTrim[i] = alpha[i+i_start];
		}

		data = dataTrim;
		alpha = alphaTrim;
		
		// Trim début + calcul offset
		// Trim fin

		AsmSourceCode src = new AsmSourceCode();
		int i_centerOffset = i_start-center;
		if (i_centerOffset != 0) {

			if (i_centerOffset <-8192 || i_centerOffset > 8191)
				throw new Exception("write ptr offset should be in the range: -8192 to 8191.");

			// Apply center offset and set 14 bit signed value
			String[] centerOffset = new String[1];
			centerOffset[0] = String.format("$%02X%02X",0b11000000 | ((i_centerOffset & 0xff00) >> 8), i_centerOffset & 0x00FF);
			src.addFdb(centerOffset);
		}

		// format
		// 00 000000          => end of data
		// 00 nnnnnn          => write ptr offset n:1,63 (6 bits unsigned)
		// 01 000000 vvvvvvvv => right pixel is transparent, v : byte to add
		// 01 nnnnnn vvvvvvvv => n : number of byte to repeat (6 bits unsigned), v : value
		// 10 000000 vvvvvvvv => left pixel is transparent, v : byte to add		
		// 10 nnnnnn vvvvvvvv ... => n : number of bytes to write (6 bits unsigned), v : value, ...
		// 11 nnnnnn nnnnnnnn => write ptr offset n:-8192,8191 (14 bits signed)

		int count_id = 1, count_nid = 1;
		boolean tr_left = false, tr_right = false;
		int i = 0, j;
		while (i < data.length) {

			tr_left = false;
			tr_right = false;
			
			if (alpha[i] != 0) {

				if ((alpha[i] & 0xf0) == 0) {
					
					// half transparent byte on left					
					tr_left = true;
					
				} else if ((alpha[i] & 0x0f) == 0) {
					
					// half transparent byte on right					
					tr_right = true;
					
				} else {
					
					// Identical values
					count_id = 1;
					j=i;
					while (j < data.length - 1 && count_id < 63 && data[j] == data[j+1] && alpha[j] != 0 && (alpha[j+1] & 0x0f) != 0 && (alpha[j+1] & 0xf0) != 0) {
						count_id++;
						j++;
					}
	
					// Different values
					count_nid = 1;
					j=i;
					while (j < data.length - 1 && count_id < 63 && data[j] != data[j+1] && alpha[j] != 0 && (alpha[j+1] & 0x0f) != 0 && (alpha[j+1] & 0xf0) != 0) {
						count_nid++;
						j++;
					}
				}
			} else if (alpha[i] == 0) {

				// Write Offset
				count_id = 1;
				j=i;
				while (j < data.length - 1 && count_id < 8191 && alpha[j] == alpha[j+1] && alpha[j] == 0) {
					count_id++;
					j++;
				}

				count_nid = 1;
			}

			if (tr_left) {
				// Write a simple value with transparency on left
				src.addFcb(new String[]{String.valueOf(0b10000000),"$"+String.format("%02X", data[i] & 0x0f)});
				i++;

			} else if (tr_right) {
				// Write a simple value with transparency on right
				src.addFcb(new String[]{String.valueOf(0b01000000),"$"+String.format("%02X", data[i] & 0xf0)});
				i++;

			} else if (alpha[i] != 0) {
				if (count_nid > 1) {

					// Write n different values
					String[] values = new String[count_nid+1];
					int k=0;
					values[k++] = String.valueOf(0b10000000 + count_nid);
					while (count_nid > 0) {
						values[k++] = "$"+String.format("%02X", data[i] & 0xff);
						i++;
						count_nid--;
					}
					src.addFcb(values);

				} else {

					// Repeat n identical values
					String[] values = new String[2];
					int k=0;
					values[k++] = String.valueOf(0b01000000 + count_id);
					values[k++] = "$"+String.format("%02X", data[i] & 0xff);
					i += count_id;
					src.addFcb(values);
				}
			} else {

				if (count_id < 64) {

					// Write Offset 6 bits unsigned
					String[] values = new String[1];
					int k=0;
					values[k++] = String.format("$%02X",count_id);
					i += count_id;
					src.addFcb(values);
				} else {

					// Write Offset 14 bits singned
					String[] values = new String[1];
					int k=0;					
					values[k++] = String.format("$%02X%02X",0b11000000 | (count_id >> 8), count_id & 0x00FF);
					i += count_id;
					src.addFdb(values);					
				}
			}

		}
		src.addFcb(new String[]{"0"}); // end of data

		List<String> asm = new ArrayList<String>();
		asm.add(src.content);
		return asm;
	}
	
	public void generateCode() {		
		try
		{
			// Process Draw Code
			// ****************************************************************			
			Files.deleteIfExists(asmDFile);
			Files.createFile(asmDFile);
			
			Files.write(asmDFile, getCodeFrameDrawHeader(), Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			String src;
			
			if (isPlane0Empty && isPlane1Empty) {	
				src = "        rts\n";				
				Files.write(asmDFile, src.getBytes(StandardCharsets.UTF_8), StandardOpenOption.APPEND);					
			} else {					
				src = "        ; this will change return address and skip bra instruction\n";
				src += "        puls  d\n";
				src += "        addd  #2\n";
				src += "        pshs  d\n";   
				src += "        ; set graphic routine parameters\n";
				
				if (!isPlane0Empty)				
					src += "        leau  @a,pcr\n";
				else
					src += "        ldu   #0\n";
				
				if (!isPlane1Empty)
					src += "        leay  @b,pcr\n";
				else
					src += "        ldy   #0\n";
				
				src += "        ; go to alt graphic routine\n";
				src += "        rts\n";				
				Files.write(asmDFile, src.getBytes(StandardCharsets.UTF_8), StandardOpenOption.APPEND);
				
				if (!isPlane0Empty) {
					src = "@a";					
					Files.write(asmDFile, src.getBytes(StandardCharsets.UTF_8), StandardOpenOption.APPEND);
					Files.write(asmDFile, spriteCode1, Charset.forName("UTF-8"), StandardOpenOption.APPEND);
				}
				if (!isPlane1Empty) {
					src = "@b";					
					Files.write(asmDFile, src.getBytes(StandardCharsets.UTF_8), StandardOpenOption.APPEND);
					Files.write(asmDFile, spriteCode2, Charset.forName("UTF-8"), StandardOpenOption.APPEND);
				}	
			}	
		} 
		catch (Exception e)
		{
			e.printStackTrace(); 
			System.out.println(e); 
		}
	}

	public static String debug80Col(byte[] b1) {
		StringBuilder strBuilder = new StringBuilder();
		int i = 0;
		for(byte val : b1) {
			if (val == 0) {
				strBuilder.append(".");
			} else {
				strBuilder.append(String.format("%01x", (val-1)&0xff));
			}
			if (++i == 80) {
				strBuilder.append(System.lineSeparator());
				i = 0;
			}
		}
		return strBuilder.toString();
	}

	public List<String> getCodeFrameDrawHeader() {
		List<String> asm = new ArrayList<String>();
		asm.add("\tINCLUDE \"./engine/constants.asm\"");
		asm.add("\tsetdp $FF");
		asm.add("\topt   c,ct");		
		asm.add("");		
		asm.add("adr_" + name);
		return asm;
	}

	public int getX_offset() {
		return x_offset;
	}

	public int getX1_offset() {
		return x1_offset;
	}	
	
	public int getY1_offset() {
		return y1_offset;
	}

	public int getX_size() {
		return x_size;
	}

	public int getY_size() {
		return y_size;
	}

	public int getEraseDataSize() {
		return 0;
	}	
}