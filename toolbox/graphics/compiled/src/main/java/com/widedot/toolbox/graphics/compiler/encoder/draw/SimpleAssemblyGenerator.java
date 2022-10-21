package com.widedot.toolbox.graphics.compiler.encoder.draw;

import java.io.File;
import java.io.IOException;
import java.nio.charset.Charset;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.util.ArrayList;
import java.util.List;

import lombok.extern.slf4j.Slf4j;

import com.widedot.m6809.util.asm.Register;
import com.widedot.toolbox.graphics.compiler.Image;
import com.widedot.toolbox.graphics.compiler.encoder.Encoder;

@Slf4j
public class SimpleAssemblyGenerator extends Encoder{

	int maxTries=500000;

	boolean FORWARD = true;
	boolean REARWARD = false;
	public String name;
	public boolean spriteCenterEven;
	private int cyclesDFrameCode;
	private int sizeDFrameCode;
	
	private int x_offset;
	private int x1_offset;
	private int y1_offset;
	private int x_size;
	private int y_size;
	
	// Code
	private List<String> spriteCode1 = new ArrayList<String>();
	private List<String> spriteCode2 = new ArrayList<String>();
	private int cyclesSpriteCode1;
	private int cyclesSpriteCode2;
	private int sizeSpriteCode1;
	private int sizeSpriteCode2;
	private int sizeDCache, cycleDCache;
	
	// Binary
	private String asmDrawFileName;
	private Path asmDFile;
	
	public static final int _NO_ALPHA = 0;
	public static final int _ALPHA = 1;
	public static final int _ODD_ALPHA = 2;
	public static final int _EVEN_ALPHA = 3;
	
	private static boolean alpha = false;
	
	public SimpleAssemblyGenerator(Image img, String destDir, int alphaOption) throws Exception {
		spriteCenterEven = (img.getCoordinate() % 2) == 0;
		name = img.getFullName();
		x1_offset = img.getSubImageX1Offset();
		y1_offset = img.getSubImageY1Offset();
		x_size = img.getSubImageXSize();
		y_size = img.getSubImageYSize();

		log.debug("\t\t\tImage:"+name);
		log.debug("\t\t\tXOffset: "+getX_offset());;
		log.debug("\t\t\tX1Offset: "+getX1_offset());
		log.debug("\t\t\tY1Offset: "+getY1_offset());
		log.debug("\t\t\tXSize: "+getX_size());
		log.debug("\t\t\tYSize: "+getY_size());	
		log.debug("\t\t\tCenter: "+img.getCoordinate());
		
		switch (alphaOption) {
		case _NO_ALPHA: alpha = false;
		        break;
		case _ALPHA: alpha = img.getAlpha();
		        break;
		case _ODD_ALPHA: alpha = img.getOddAlpha();
        		break;
		case _EVEN_ALPHA: alpha = img.getEvenAlpha();
        		break;
        default: alpha = false;
		}
		log.debug("\t\t\tAlpha: "+alpha);
		
		destDir += "/"+name;
		asmDrawFileName = destDir+".asm";
		File file = new File (asmDrawFileName);
		file.getParentFile().mkdirs();		
		asmDFile = Paths.get(asmDrawFileName);
		
		PatternFinder cs = new PatternFinder(img.getSubImagePixels(0));
		cs.buildCode(REARWARD);
		Solution solution = cs.getSolutions().get(0);

		PatternCluster cluster = new PatternCluster(solution, img.getCoordinate());
		cluster.cluster(REARWARD);

		SolutionOptim regOpt = new SolutionOptim(solution, img.getSubImageData(0), maxTries);
		regOpt.build();

		spriteCode1 = regOpt.getAsmCode();
		cyclesSpriteCode1 = regOpt.getAsmCodeCycles();
		sizeSpriteCode1 = regOpt.getAsmCodeSize();

		cs = new PatternFinder(img.getSubImagePixels(1));
		cs.buildCode(REARWARD);
		solution = cs.getSolutions().get(0);

		cluster = new PatternCluster(solution, img.getCoordinate());
		cluster.cluster(REARWARD);

		regOpt = new SolutionOptim(solution, img.getSubImageData(1), maxTries);
		regOpt.build();

		spriteCode2 = regOpt.getAsmCode();	
		cyclesSpriteCode2 = regOpt.getAsmCodeCycles();
		sizeSpriteCode2 = regOpt.getAsmCodeSize();

		// Calcul des cycles et taille du code de cadre
		cyclesDFrameCode = 0;
		cyclesDFrameCode += getCodeFrameDrawStartCycles(alpha);
		cyclesDFrameCode += getCodeFrameDrawMidCycles();
		cyclesDFrameCode += getCodeFrameDrawEndCycles();

		sizeDFrameCode = 0;
		sizeDFrameCode += getCodeFrameDrawStartSize(alpha);
		sizeDFrameCode += getCodeFrameDrawMidSize();
		sizeDFrameCode += getCodeFrameDrawEndSize();					
	}
	
	public void generateCode() {		
		try
		{
			// Process Draw Code
			// ****************************************************************			
			Files.deleteIfExists(asmDFile);
			Files.createFile(asmDFile);

			Files.write(asmDFile, getCodeFrameDrawStart(alpha), Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			Files.write(asmDFile, spriteCode1, Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			Files.write(asmDFile, getCodeFrameDrawMid(), Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			Files.write(asmDFile, spriteCode2, Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			Files.write(asmDFile, getCodeFrameDrawEnd(), Charset.forName("UTF-8"), StandardOpenOption.APPEND);

			int computedDSize = getDSize();
			
			if (computedDSize > 16384) {
				throw new Exception("\t\t\t" + " Le code généré ("+computedDSize+" octets) dépasse la taille d'une page", new Exception("Prérequis."));
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

	public List<String> getCodeFrameDrawStart(boolean alphaFlag) {
		List<String> asm = new ArrayList<String>();
		asm.add("\tINCLUDE \"./engine/constants.asm\"");		
		asm.add("\tSETDP $FF");
		asm.add("\tOPT C,CT");		
		asm.add("adr_" + name);
		if (alphaFlag) {
			asm.add("\n\tstb   <glb_alphaTiles"); // tile rendering use b to load ram page, only 4 cycles in direct mode, better than inc
		}
		return asm;
	}

	public int getCodeFrameDrawStartCycles(boolean alphaFlag) throws Exception {
		int cycles = 0;
		if (alphaFlag) {
			cycles += Register.costDirectST[Register.B];
		}		
		return cycles;
	}

	public int getCodeFrameDrawStartSize(boolean alphaFlag) throws Exception {
		int size = 0;
		if (alphaFlag) {
			size += Register.sizeDirectST[Register.B];
		}		
		return size;
	}

	public List<String> getCodeFrameDrawMid() {
		List<String> asm = new ArrayList<String>();
		asm.add("\n\tLDU <glb_screen_location_1");		
		return asm;
	}

	public int getCodeFrameDrawMidCycles() {
		int cycles = 0;
		cycles += Register.costDirectLD[Register.U];
		return cycles;
	}

	public int getCodeFrameDrawMidSize() {
		int size = 0;
		size += Register.sizeDirectLD[Register.U];
		return size;
	}

	public List<String> getCodeFrameDrawEnd() {
		List<String> asm = new ArrayList<String>();
		asm.add("\tRTS\n");
		return asm;
	}

	public int getCodeFrameDrawEndCycles() {
		int cycles = 0;
		cycles += 5; // RTS
		return cycles;
	}

	public int getCodeFrameDrawEndSize() {
		int size = 0;
		size += 1; // RTS
		return size;
	}

	public int getDCycles() {
		return cyclesDFrameCode + cyclesSpriteCode1 + cyclesSpriteCode2 + cycleDCache;
	}

	public int getDSize() throws IOException {
		return sizeDFrameCode + sizeSpriteCode1 + sizeSpriteCode2 + sizeDCache;
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