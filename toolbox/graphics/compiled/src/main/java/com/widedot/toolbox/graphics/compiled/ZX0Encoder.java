package com.widedot.toolbox.graphics.compiled;

import java.io.File;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import com.widedot.m6809.gamebuilder.util.asm.AsmSourceCode;
import com.widedot.m6809.gamebuilder.util.graphics.Image;
import com.widedot.m6809.gamebuilder.util.zx0.Compressor;
import com.widedot.m6809.gamebuilder.util.zx0.Optimizer;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class ZX0Encoder extends Encoder{

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
	private int center;
	
	// Code
	private List<String> spriteCode1 = new ArrayList<String>();
	private List<String> spriteCode2 = new ArrayList<String>();
	
	// Binary
	private String asmDrawFileName;
	private Path asmDFile;
	
	public ZX0Encoder(Image img, String destDir) throws Exception {
		spriteCenterEven = (img.center % 2) == 0;
		name = img.getName()+"_"+img.getType();
		x1_offset = img.getSubImageX1Offset();
		y1_offset = img.getSubImageY1Offset();
		x_size = img.getSubImageXSize();
		y_size = img.getSubImageYSize();
		isPlane0Empty = img.isPlane0Empty();
		isPlane1Empty = img.isPlane1Empty();		
		center = img.getCenter();

		log.debug("\t\t\tImage:"+name);
		log.debug("\t\t\tXOffset: "+getX_offset());;
		log.debug("\t\t\tX1Offset: "+getX1_offset());
		log.debug("\t\t\tY1Offset: "+getY1_offset());
		log.debug("\t\t\tXSize: "+getX_size());
		log.debug("\t\t\tYSize: "+getY_size());	
		log.debug("\t\t\tCenter: "+img.getCenter());
		
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
				//log.debug(debug80Col(img.getSubImagePixels(, 0)));
			
			if (!isPlane0Empty)
				spriteCode1	= encode(img.getSubImagePixels(0), img.getCenter(), "0");

			//log.debug("\t\t\tRAM 1 (val hex 0  à f par pixel, . Transparent):");
			//if (log.isDebugEnabled())
				//log.debug(debug80Col(img.getSubImagePixels(, 1)));

			if (!isPlane0Empty)
				spriteCode2	= encode(img.getSubImagePixels(1), img.getCenter(), "1");
			
		}
	}
	
	public List<String> encode(byte[] dataIn, int center, String id) throws Exception {
		AsmSourceCode src = new AsmSourceCode();
		byte[] output = null;
        int[] delta = { 0 };
        
        // takes a dataIn table (values 0-16 : 0 transparent color, 1-16 colors)
        // split into two tables :
        // data : 0-15 colors (transparency is lost and now share the same index with color 0)
        // alpha : transparency mask 0-1 (0 : transparent, 1 : opaque)
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

		// only process color data, transparency is lost
        output = new Compressor().compress(new Optimizer().optimize(data, 0, 32640, 4, true), data, 0, false, false, delta);
        src.addFcb(output);
        
		List<String> asm = new ArrayList<String>();
		asm.add(src.content);
		return asm;
	}
	
	public void compileCode(String org) {		
		try
		{
			Pattern pt = Pattern.compile("[ \t]*ORG[ \t]*\\$[a-fA-F0-9]{4}");
			Process p;
			
			// Process Draw Code
			// ****************************************************************			
			if (!(Files.exists(asmDFile))) {
				Files.deleteIfExists(asmDFile);
				Files.createFile(asmDFile);
				
				Files.write(asmDFile, getCodeFrameDrawHeader(org), Charset.forName("UTF-8"), StandardOpenOption.APPEND);
				String src;
				
				if (isPlane0Empty && isPlane1Empty) {	
					src = "        rts\n";				
					Files.write(asmDFile, src.getBytes(StandardCharsets.UTF_8), StandardOpenOption.APPEND);					
				} else {					
					src = "        ; this will change return address and skip bra instruction\n";
					src += "        puls  d\n";
					src += "        addd  #7\n";
					src += "        pshs  d\n";   
					src += "        ; set graphic routine parameters\n";
					
					if (!isPlane0Empty) {
					    src += "        ldx   <glb_screen_location_1\n";
					    src += "        leax  "+(-center)+",x\n";
					    src += "        stx   <glb_screen_location_1\n";								
						src += "        leau  @a,pcr\n";			    
					} else {
						src += "        ldu   #0\n";
					}
					if (!isPlane1Empty) {
					    src += "        ldx   <glb_screen_location_2\n";
					    src += "        leax  "+(-center)+",x\n";
					    src += "        stx   <glb_screen_location_2\n";								
						src += "        leax  @b,pcr\n";
					} else {
						src += "        ldx   #0\n";
					}
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
				
			} else {
				// change ORG adress in existing ASM file
				String str = new String(Files.readAllBytes(asmDFile), StandardCharsets.UTF_8);
				Matcher m = pt.matcher(str);
				if (m.find()) {
					str = m.replaceFirst("\tORG \\$"+org);
				}
				Files.write(asmDFile, str.getBytes(StandardCharsets.UTF_8));
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

	public List<String> getCodeFrameDrawHeader(String org) {
		List<String> asm = new ArrayList<String>();
		asm.add("\tINCLUDE \"./engine/constants.asm\"");
		asm.add("");
		asm.add("\torg   $" + org + "");
		asm.add("\tsetdp $FF");
		asm.add("\topt   c,ct");		
		asm.add("");		
		asm.add("adr_" + name );
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
