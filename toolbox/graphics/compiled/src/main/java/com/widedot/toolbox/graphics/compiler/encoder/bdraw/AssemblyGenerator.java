package com.widedot.toolbox.graphics.compiler.encoder.bdraw;

import java.io.File;
import java.nio.charset.Charset;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.util.ArrayList;
import java.util.List;

import com.widedot.m6809.util.asm.Register;
import com.widedot.toolbox.graphics.compiler.Image;
import com.widedot.toolbox.graphics.compiler.encoder.Encoder;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class AssemblyGenerator extends Encoder{
	
	int maxTries=500000;
	
	public static String ERASE_SUFFIXE = "_erase";

	boolean FORWARD = true;
	public String name;
	public boolean spriteCenterEven;
	private int cyclesDFrameCode;
	private int sizeDFrameCode;
	private int cyclesEFrameCode;
	private int sizeEFrameCode;
	
	private int x1_offset;
	private int y1_offset;
	private int x_size;
	private int y_size;

	// Code
	private List<String> spriteCode1 = new ArrayList<String>();
	private List<String> spriteCode2 = new ArrayList<String>();
	private List<String> spriteECode1 = new ArrayList<String>();
	private List<String> spriteECode2 = new ArrayList<String>();
	private int cyclesSpriteCode1;
	private int cyclesSpriteCode2;
	private int cyclesSpriteECode1;
	private int cyclesSpriteECode2;
	private int sizeSpriteCode1;
	private int sizeSpriteCode2;
	private int sizeSpriteECode1;
	private int sizeSpriteECode2;
	private int sizeSpriteEData1;
	private int sizeSpriteEData2;
	private int sizeDCache, cycleDCache, sizeECache, cycleECache;
	
	// Binary
	private String asmBckDrawFileName;
	private String asmEraseFileName;
	private Path asmDFile;
	private Path asmEFile;	

	public AssemblyGenerator(Image img, String destDir) throws Exception {
		name = img.getFullName();
		spriteCenterEven = (img.getCoordinate() % 2) == 0;
		x1_offset = img.getSubImageX1Offset();
		y1_offset = img.getSubImageY1Offset();
		x_size = img.getSubImageXSize();
		y_size = img.getSubImageYSize();

		log.debug("\t\t\tImage:"+name);
		log.debug("\t\t\tX1Offset: "+getX1_offset());
		log.debug("\t\t\tY1Offset: "+getY1_offset());
		log.debug("\t\t\tXSize: "+getX_size());
		log.debug("\t\t\tYSize: "+getY_size());		
		log.debug("\t\t\tCenter: "+img.getCoordinate());
		
		destDir += "/"+name;
		asmBckDrawFileName = destDir+".asm";
		File file = new File (asmBckDrawFileName);
		file.getParentFile().mkdirs();		
		asmDFile = Paths.get(asmBckDrawFileName);
		
		asmEraseFileName = destDir+ERASE_SUFFIXE+".asm";
		asmEFile = Paths.get(asmEraseFileName);

		PatternFinder cs = new PatternFinder(img.getSubImagePixels( 0));
		cs.buildCode(FORWARD);
		Solution solution = cs.getSolutions().get(0);

		PatternCluster cluster = new PatternCluster(solution, img.getCoordinate());
		cluster.cluster(FORWARD);

		SolutionOptim regOpt = new SolutionOptim(solution, img.getSubImageData( 0), maxTries);
		regOpt.build();

		spriteCode1 = regOpt.getAsmCode();
		cyclesSpriteCode1 = regOpt.getAsmCodeCycles();
		sizeSpriteCode1 = regOpt.getAsmCodeSize();

		spriteECode1 = regOpt.getAsmECode();
		cyclesSpriteECode1 = regOpt.getAsmECodeCycles();
		sizeSpriteECode1 = regOpt.getAsmECodeSize();

		sizeSpriteEData1 = regOpt.getDataSize();

		cs = new PatternFinder(img.getSubImagePixels(1));
		cs.buildCode(FORWARD);
		solution = cs.getSolutions().get(0);

		cluster = new PatternCluster(solution, img.getCoordinate());
		cluster.cluster(FORWARD);

		regOpt = new SolutionOptim(solution, img.getSubImageData(1), maxTries);
		regOpt.build();

		spriteCode2 = regOpt.getAsmCode();	
		cyclesSpriteCode2 = regOpt.getAsmCodeCycles();
		sizeSpriteCode2 = regOpt.getAsmCodeSize();

		spriteECode2 = regOpt.getAsmECode();
		cyclesSpriteECode2 = regOpt.getAsmECodeCycles();
		sizeSpriteECode2 = regOpt.getAsmECodeSize();

		sizeSpriteEData2 = regOpt.getDataSize();
		// cell size is expected to be 64 in asm engine, value 12 is the number of bytes used by IRQ to save all registers
		// in all irq routines, stack is moved to a dedicated buffer in irq, thus no need to go higher than 12
		img.nb_cell = (getEraseDataSize() + 12 + 64 - 1) / 64;

		// Calcul des cycles et taille du code de cadre
		cyclesDFrameCode = 0;
		cyclesDFrameCode += getCodeFrameBckDrawStartCycles();
		cyclesDFrameCode += getCodeFrameBckDrawMidCycles();
		cyclesDFrameCode += getCodeFrameBckDrawEndCycles();

		sizeDFrameCode = 0;
		sizeDFrameCode += getCodeFrameBckDrawStartSize();
		sizeDFrameCode += getCodeFrameBckDrawMidSize();
		sizeDFrameCode += getCodeFrameBckDrawEndSize();			
		
		cyclesEFrameCode = 0;
		cyclesEFrameCode += getCodeFrameEraseStartCycles();			
		cyclesEFrameCode += getCodeFrameEraseEndCycles();

		sizeEFrameCode = 0;
		sizeEFrameCode += getCodeFrameEraseStartSize();			
		sizeEFrameCode += getCodeFrameEraseEndSize();			
	}
	
	public void generateCode() {		
		try
		{
			
			// Process BckDraw Code
			// ****************************************************************			
			Files.deleteIfExists(asmDFile);
			Files.createFile(asmDFile);

			Files.write(asmDFile, getCodeFrameBckDrawStart(), Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			Files.write(asmDFile, spriteCode1, Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			Files.write(asmDFile, getCodeFrameBckDrawMid(), Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			Files.write(asmDFile, spriteCode2, Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			Files.write(asmDFile, getCodeFrameBckDrawEnd(), Charset.forName("UTF-8"), StandardOpenOption.APPEND);

			log.debug("\t\t\tSize: "+getDSize());
			log.debug("\t\t\tCycles: "+getDCycles());
			
			int computedDSize = getDSize();
			
			if (computedDSize > 16384) {
				throw new Exception("\t\t\t" + " Le code généré ("+computedDSize+" octets) dépasse la taille d'une page", new Exception("Prérequis."));
			}			

			// Process Erase Code
			// ****************************************************************
			Files.deleteIfExists(asmEFile);
			Files.createFile(asmEFile);
			
			List<String> dataSize = new ArrayList<String>();
			dataSize.add(String.format(name+"_datasize equ $%1$04X", getEraseDataSize() & 0xFFFF));
			
			Files.write(asmEFile, getCodeFrameEraseStart(), Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			Files.write(asmEFile, spriteECode2, Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			Files.write(asmEFile, spriteECode1, Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			Files.write(asmEFile, getCodeFrameEraseEnd(), Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			Files.write(asmEFile, dataSize, Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			
			log.debug("\t\t\tE Size: "+getESize());
			log.debug("\t\t\tE Cycles: "+getECycles());
			
			int computedESize = getESize();

			if (computedESize > 16384) {
				throw new Exception("\t\t\t" + " Le code généré ("+computedESize+" octets) dépasse la taille d'une page", new Exception("Prérequis."));
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

	public List<String> getCodeFrameBckDrawStart() {
		List<String> asm = new ArrayList<String>();
		asm.add("\tINCLUDE \"./engine/constants.asm\"");
		asm.add("\tOPT C,CT");
		asm.add("adr_" + name);
		asm.add("\tSTS glb_register_s\n");
		asm.add("\tLEAS ,Y");
		return asm;
	}

	public int getCodeFrameBckDrawStartCycles() throws Exception {
		int cycles = 0;
		cycles += Register.costExtendedST[Register.S];
		cycles += Register.costIndexedLEA;
		return cycles;
	}

	public int getCodeFrameBckDrawStartSize() throws Exception {
		int size = 0;
		size += Register.sizeExtendedST[Register.S];
		size += Register.sizeIndexedLEA;		
		return size;
	}

	public List<String> getCodeFrameBckDrawMid() {
		List<String> asm = new ArrayList<String>();
		asm.add("\n\tLDU <glb_screen_location_1");		
		return asm;
	}

	public int getCodeFrameBckDrawMidCycles() {
		int cycles = 0;
		cycles += Register.costDirectLD[Register.U];
		return cycles;
	}

	public int getCodeFrameBckDrawMidSize() {
		int size = 0;
		size += Register.sizeDirectLD[Register.U];
		return size;
	}

	public List<String> getCodeFrameBckDrawEnd() {
		List<String> asm = new ArrayList<String>();
		asm.add("\tLEAU ,S");
		asm.add("\tLDS glb_register_s");
		asm.add("\tRTS\n");
		return asm;
	}

	public int getCodeFrameBckDrawEndCycles() {
		int cycles = 0;
		cycles += Register.costIndexedLEA;
		cycles += Register.costExtendedLD[Register.S];
		cycles += 5; // RTS
		return cycles;
	}

	public int getCodeFrameBckDrawEndSize() {
		int size = 0;
		size += Register.sizeIndexedLEA;
		size += Register.sizeExtendedLD[Register.S];
		size += 1; // RTS
		return size;
	}

	public List<String> getCodeFrameEraseStart() {
		List<String> asm = new ArrayList<String>();
		asm.add("\tINCLUDE \"./engine/constants.asm\"");		
		asm.add("\tOPT C,CT");		
		asm.add("adr_" + name + ERASE_SUFFIXE);
		asm.add("\tSTS glb_register_s\n");
		asm.add("\tLEAS ,U");                                // usage de S a cause des irq musique
		return asm;
	}

	public int getCodeFrameEraseStartCycles() throws Exception {
		int cycles = 0;
		cycles += Register.costExtendedST[Register.S];
		cycles += Register.costIndexedLEA;
		return cycles;
	}

	public int getCodeFrameEraseStartSize() throws Exception {
		int size = 0;
		size += Register.sizeExtendedST[Register.S];
		size += Register.sizeIndexedLEA;	
		return size;
	}	
	
	public List<String> getCodeFrameEraseEnd() {
		List<String> asm = new ArrayList<String>();
		asm.add("\tLEAU ,S");
		asm.add("\tLDS glb_register_s");
		asm.add("\tRTS\n");
		return asm;
	}

	public int getCodeFrameEraseEndCycles() {
		int cycles = 0;
		cycles += Register.costIndexedLEA;
		cycles += Register.costExtendedLD[Register.S];
		cycles += 5; // RTS
		return cycles;
	}

	public int getCodeFrameEraseEndSize() {
		int size = 0;
		size += Register.sizeIndexedLEA;
		size += Register.sizeExtendedLD[Register.S];	
		size += 1; // RTS
		return size;
	}

	public int getDCycles() {
		return cyclesDFrameCode + cyclesSpriteCode1 + cyclesSpriteCode2 + cycleDCache;
	}

	public int getDSize() {
		return sizeDFrameCode + sizeSpriteCode1 + sizeSpriteCode2 + sizeDCache;
	}
	
	public int getECycles() {
		return cyclesEFrameCode + cyclesSpriteECode1 + cyclesSpriteECode2 + cycleECache;
	}

	public int getESize() {
		return sizeEFrameCode + sizeSpriteECode1 + sizeSpriteECode2 + sizeECache;
	}

	public int getSizeData1() {
		return sizeSpriteEData1;
	}

	public int getSizeData2() {
		return sizeSpriteEData2;
	}
	
	public int getEraseDataSize() {
		return sizeSpriteEData1+sizeSpriteEData2;
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

}