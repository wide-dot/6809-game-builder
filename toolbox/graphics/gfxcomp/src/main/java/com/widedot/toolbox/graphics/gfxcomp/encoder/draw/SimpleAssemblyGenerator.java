package com.widedot.toolbox.graphics.gfxcomp.encoder.draw;

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
import com.widedot.toolbox.graphics.gfxcomp.Image;
import com.widedot.toolbox.graphics.gfxcomp.encoder.Encoder;
import com.widedot.toolbox.graphics.gfxcomp.setting.VideoMemory;

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
	
	private boolean alpha = false;   // per generator, not shared : v1 has it on the instance
	
	/** how the second plane is reached ; see Image.PLANES_* */
	private final String planes;

	/** planes=cursor : the LEAY that leaves Y on the next cell, 0 when the code lands there */
	private int yReturn;
	private int yReturnCycles;
	private int yReturnSize;

	public SimpleAssemblyGenerator(Image img, String destDir, int alphaOption) throws Exception {
		planes = img.planes;
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

		// bm4s : the half transparent pairs, laid apart (each byte with its
		// pixels' mask) before the plane's code, U on the anchor still
		int[] cost = new int[2];
		spriteCode1 = withHalves(img, 0, spriteCode1, cost);
		cyclesSpriteCode1 += cost[0];
		sizeSpriteCode1 += cost[1];
		cost = new int[2];
		spriteCode2 = withHalves(img, 1, spriteCode2, cost);
		cyclesSpriteCode2 += cost[0];
		sizeSpriteCode2 += cost[1];

		if (planesByCursor()) {
			secondPlaneThroughY(img);
		}

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

			log.debug("\t\t\tSize: "+getDSize());
			log.debug("\t\t\tCycles: "+getDCycles());
			
			int computedDSize = getDSize();
			
			if (computedDSize > 16384) {
				throw new Exception("\t\t\t" + " Le code généré ("+computedDSize+" octets) dépasse la taille d'une page", new Exception("Prérequis."));
			}			
		} 
		catch (Exception e)
		{
			// the page overflow check above is only worth having if it stops
			// the build : an oversized routine would otherwise overrun its page
			// at run time
			throw new RuntimeException(e);
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

	/**
	 * bm4s, a plane's half transparent pairs (Image.getHalfPixels : 1-4 the
	 * left pixel opaque in the colour 0-3, 5-8 the right one) : the planes'
	 * pattern code leaves them transparent ; each byte holding one is laid
	 * here, LDA / ANDA with its opaque pixels' two bits cleared / ORA their
	 * colour / STA, at its offset from the anchor (the code's first LEAU
	 * starts from there). A bm4s pixel is a byte's two bits, leftmost first :
	 * the packed pixel at an even index is the byte's high nibble. cost : the
	 * cycles and the bytes added.
	 */
	// the toolchain signals build errors with plain Exceptions (48 throw sites)
	@SuppressWarnings("PMD.AvoidThrowingRawExceptionTypes")
	private static List<String> withHalves(Image img, int page, List<String> code, int[] cost) throws Exception {
		byte[] half = img.getHalfPixels(page);
		if (half == null) {
			return code;
		}
		java.util.TreeMap<Integer, int[]> bytes = new java.util.TreeMap<Integer, int[]>();
		for (int i = 0; i < half.length; i++) {
			int v = half[i] & 0xff;
			if (v == 0) {
				continue;
			}
			boolean left = v <= 4;
			int bits = (i % 2 == 0 ? 4 : 0) + (left ? 2 : 0);
			int[] maskValue = bytes.computeIfAbsent(i / 2, k -> new int[] {0xff, 0});
			maskValue[0] &= ~(3 << bits);
			maskValue[1] |= ((v - 1) & 3) << bits;
		}
		List<String> out = new ArrayList<String>();
		for (java.util.Map.Entry<Integer, int[]> e : bytes.entrySet()) {
			int offset = e.getKey() - img.getCoordinate();
			out.add(String.format("\tLDA %d,U\n\tANDA #$%02X\n\tORA #$%02X\n\tSTA %d,U",
					offset, e.getValue()[0] & 0xff, e.getValue()[1], offset));
			cost[0] += Register.costIndexedLD[Register.A] + Register.costImmediateAND[Register.A]
					+ Register.costImmediateOR[Register.A] + Register.costIndexedST[Register.A]
					+ 2 * Register.getIndexedOffsetCost(offset);
			cost[1] += Register.sizeIndexedLD[Register.A] + Register.sizeImmediateAND[Register.A]
					+ Register.sizeImmediateOR[Register.A] + Register.sizeIndexedST[Register.A]
					+ 2 * Register.getIndexedOffsetSize(offset);
		}
		out.addAll(code);
		return out;
	}

	/** true when the code walks to the second plane instead of pointing at it */
	private boolean planesByOffset() {
		return Image.PLANES_OFFSET.equals(planes);
	}

	/** true when the second plane is the caller's Y, given back on the next cell */
	private boolean planesByCursor() {
		return Image.PLANES_CURSOR.equals(planes);
	}

	/**
	 * planes=cursor : the second plane's code addresses Y instead of U (the same
	 * indexed forms, at the same cost), and a final LEAY leaves Y one cell
	 * further : the image's width in plane bytes from where the caller had it.
	 * The caller walks its row with X and Y, so code using either as data is
	 * refused rather than emitted.
	 */
	// the toolchain signals build errors with plain Exceptions (48 throw sites)
	@SuppressWarnings("PMD.AvoidThrowingRawExceptionTypes")
	private void secondPlaneThroughY(Image img) throws Exception {
		for (List<String> code : List.of(spriteCode1, spriteCode2)) {
			for (String element : code) {
				for (String line : element.split("\n")) {
					if (usesXorY(line)) {
						throw new Exception("image " + name + " : planes=" + Image.PLANES_CURSOR
								+ " keeps the caller's X and Y, this code needs one of them : " + line.trim());
					}
				}
			}
		}
		int moved = 0;
		List<String> code = new ArrayList<String>();
		for (String element : spriteCode2) {
			StringBuilder converted = new StringBuilder();
			for (String line : element.split("\n", -1)) {
				String op = line.trim();
				if (op.toUpperCase().startsWith("LEAU")) {
					moved += Integer.parseInt(op.substring(4, op.indexOf(',')).trim());
				}
				if (converted.length() > 0) {
					converted.append('\n');
				}
				converted.append(line.replaceFirst("(?i)^(\\s*)LEAU", "$1LEAY").replaceFirst("(?i),U(\\s*)$", ",Y$1"));
			}
			code.add(converted.toString());
		}
		spriteCode2 = code;
		int pixelsPerByte = VideoMemory.memoryPlanarBits / VideoMemory.memoryLinearBits;
		int cellBytes = pixelsPerByte * VideoMemory.memoryNbPlanes;
		if (img.getWidth() % cellBytes != 0) {
			throw new Exception("image " + name + " : planes=" + Image.PLANES_CURSOR + " needs a width in whole plane bytes ("
					+ cellBytes + " pixels), got " + img.getWidth());
		}
		yReturn = img.getWidth() / cellBytes - moved;
		if (yReturn != 0) {
			// LEAY : 4 cycles and 2 bytes, plus its offset's indexing
			yReturnCycles = 4 + Register.getIndexedOffsetCost(yReturn);
			yReturnSize = 2 + Register.getIndexedOffsetSize(yReturn);
		}
	}

	/** an instruction that reads or writes X or Y, or pushes or pulls registers */
	private static boolean usesXorY(String line) {
		String op = line.trim().toUpperCase();
		return op.matches("^(LD|ST|LEA|CMP)[XY]\\b.*") || op.matches("^(ABX|PSHU|PULU|PSHS|PULS|EXG|TFR)\\b.*")
				|| op.matches(".*,-*[XY]\\+*$");
	}

	public List<String> getCodeFrameDrawMid() {
		List<String> asm = new ArrayList<String>();
		if (planesByOffset()) {
			asm.add("\n\tLEAU  -" + VideoMemory.memoryPlaneDistance + ",U");
		} else if (!planesByCursor()) {
			asm.add("\n\tLDU <glb_screen_location_1");
		}
		return asm;
	}

	public int getCodeFrameDrawMidCycles() {
		int cycles = 0;
		// LEAU n16,U : 4 base + 5 for the 16 bit offset indexing mode
		if (!planesByCursor()) {
			cycles += planesByOffset() ? 9 : Register.costDirectLD[Register.U];
		}
		return cycles;
	}

	public int getCodeFrameDrawMidSize() {
		int size = 0;
		// LEAU n16,U : opcode + postbyte + two offset bytes
		if (!planesByCursor()) {
			size += planesByOffset() ? 4 : Register.sizeDirectLD[Register.U];
		}
		return size;
	}

	public List<String> getCodeFrameDrawEnd() {
		List<String> asm = new ArrayList<String>();
		if (planesByOffset()) {
			// U is the caller's cursor over a row of sprites : give it back
			asm.add("\tLEAU  " + VideoMemory.memoryPlaneDistance + ",U");
		}
		if (planesByCursor() && yReturn != 0) {
			asm.add("\tLEAY  " + yReturn + ",Y");
		}
		asm.add("\tRTS\n");
		return asm;
	}

	public int getCodeFrameDrawEndCycles() {
		int cycles = 0;
		if (planesByOffset()) {
			cycles += 9; // LEAU n16,U
		}
		cycles += yReturnCycles;
		cycles += 5; // RTS
		return cycles;
	}

	public int getCodeFrameDrawEndSize() {
		int size = 0;
		if (planesByOffset()) {
			size += 4; // LEAU n16,U
		}
		size += yReturnSize;
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
