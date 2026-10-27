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
		// pixels' mask) before the plane's code
		int[] cost = new int[2];
		spriteCode1 = withHalves(img, 0, spriteCode1, !planesByPointer() || !spriteCode1.isEmpty(), cost);
		cyclesSpriteCode1 += cost[0];
		sizeSpriteCode1 += cost[1];
		cost = new int[2];
		spriteCode2 = withHalves(img, 1, spriteCode2, !planesByPointer() || !spriteCode2.isEmpty(), cost);
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
	 * left pixel opaque in the colour 0-3, 5-8 the right one, 9-24 both) :
	 * the plane's pattern code leaves their bytes alone ; each is laid here,
	 * once for its four pixels : read, AND clearing its opaque pixels' bits
	 * (left out when the colours set them all), OR their colours (left out
	 * when all 0), written back. Two neighbour bytes go through D. A bm4s
	 * pixel is two bits of a byte, leftmost first : the packed pixel at an
	 * even index is the byte's high nibble.
	 *
	 * The writes run before the pattern code, U walking between them : where
	 * to move it (LEAU) is chosen by dynamic programming over the bytes in
	 * address order, so that each is reached through the shortest offset
	 * (none, 5 or 8 bits rather than 16), bytes first and cycles next. The
	 * walk is folded into the pattern code's first LEAU, which starts from the
	 * anchor, so U is where that code expects it. cost : cycles and bytes added.
	 */
	// the toolchain signals build errors with plain Exceptions (48 throw sites)
	@SuppressWarnings("PMD.AvoidThrowingRawExceptionTypes")
	private static List<String> withHalves(Image img, int page, List<String> code, boolean restoreU, int[] cost) throws Exception {
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
			int shiftBits = i % 2 == 0 ? 4 : 0;
			int[] mv = bytes.computeIfAbsent(i / 2, k -> new int[] {0xff, 0});
			if (v > 8) {
				mv[0] &= ~(0xf << shiftBits);
				mv[1] |= (v - 9) << shiftBits;
			} else {
				int bits = shiftBits + (v <= 4 ? 2 : 0);
				mv[0] &= ~(3 << bits);
				mv[1] |= ((v - 1) & 3) << bits;
			}
		}
		if (bytes.isEmpty()) {
			return code;
		}
		// the writes : one byte, or two neighbours through D
		List<int[]> ops = new ArrayList<int[]>();   // offset, width, mask0, value0, mask1, value1
		Integer[] keys = bytes.keySet().toArray(new Integer[0]);
		for (int k = 0; k < keys.length; k++) {
			int offset = keys[k] - img.getCoordinate();
			int[] m0 = bytes.get(keys[k]);
			if (k + 1 < keys.length && keys[k + 1] == keys[k] + 1) {
				int[] m1 = bytes.get(keys[k + 1]);
				ops.add(new int[] {offset, 2, m0[0], m0[1], m1[0], m1[1]});
				k++;
			} else {
				ops.add(new int[] {offset, 1, m0[0], m0[1], 0, 0});
			}
		}
		// the pattern code's first LEAU, from the anchor
		int leau = -1;
		Integer first = null;
		for (int e = 0; e < code.size() && leau < 0; e++) {
			String[] lines = code.get(e).split("\n", -1);
			for (int l = 0; l < lines.length; l++) {
				String op = lines[l].trim();
				if (op.isEmpty()) {
					continue;
				}
				java.util.regex.Matcher m = java.util.regex.Pattern.compile("(?i)^LEAU\\s+(-?\\d+),U$").matcher(op);
				if (m.matches()) {
					first = Integer.parseInt(m.group(1));
					leau = e;
				}
				break;
			}
			if (leau < 0 && code.get(e).trim().length() > 0) {
				break;
			}
		}
		// dynamic programming : per write, the cheapest walk ending with U on
		// each candidate place (the anchor, or a write's place, or 16 or 128
		// bytes past it : the reach of a 5 and an 8 bit offset)
		java.util.List<java.util.Map<Integer, long[]>> best = new ArrayList<>();   // cursor -> cost, previous cursor
		java.util.Map<Integer, long[]> cur = new java.util.HashMap<>();
		cur.put(0, new long[] {0, 0});
		for (int[] op : ops) {
			java.util.Map<Integer, long[]> next = new java.util.HashMap<>();
			for (java.util.Map.Entry<Integer, long[]> e : cur.entrySet()) {
				int c = e.getKey();
				for (int t : new int[] {Integer.MIN_VALUE, 0, 16, 128}) {
					int to = t == Integer.MIN_VALUE ? c : op[0] + t;
					long move = to == c ? 0 : weight(leaSize(to - c), leaCycles(to - c));
					long total = e.getValue()[0] + move + weight(writeSize(op, op[0] - to), writeCycles(op, op[0] - to));
					long[] known = next.get(to);
					if (known == null || total < known[0]) {
						next.put(to, new long[] {total, c});
					}
				}
			}
			best.add(next);
			cur = next;
		}
		// the end : U back where the pattern code expects it
		int end = 0;
		long endCost = Long.MAX_VALUE;
		for (java.util.Map.Entry<Integer, long[]> e : cur.entrySet()) {
			long total = e.getValue()[0] + weight(back(e.getKey(), first, restoreU, 0), back(e.getKey(), first, restoreU, 1));
			if (total < endCost) {
				endCost = total;
				end = e.getKey();
			}
		}
		int[] cursors = new int[ops.size()];
		int c = end;
		for (int k = ops.size() - 1; k >= 0; k--) {
			cursors[k] = c;
			c = (int) best.get(k).get(c)[1];
		}
		List<String> out = new ArrayList<String>();
		c = 0;
		for (int k = 0; k < ops.size(); k++) {
			int[] op = ops.get(k);
			if (cursors[k] != c) {
				out.add("\tLEAU " + (cursors[k] - c) + ",U");
				cost[0] += leaCycles(cursors[k] - c);
				cost[1] += leaSize(cursors[k] - c);
				c = cursors[k];
			}
			out.add(write(op, op[0] - c));
			cost[0] += writeCycles(op, op[0] - c);
			cost[1] += writeSize(op, op[0] - c);
		}
		cost[0] += back(c, first, restoreU, 1);
		cost[1] += back(c, first, restoreU, 0);
		List<String> rest = new ArrayList<String>(code);
		if (first != null) {
			String element = rest.get(leau);
			String moved = first - c == 0 ? "" : "\tLEAU " + (first - c) + ",U";
			rest.set(leau, element.replaceFirst("(?i)LEAU\\s+-?\\d+,U", moved));
		} else if (c != 0 && restoreU) {
			out.add("\tLEAU " + (-c) + ",U");
		}
		out.addAll(rest);
		return out;
	}

	/** bytes first, cycles next */
	private static long weight(int size, int cycles) {
		return size * 1000L + cycles;
	}

	private static int leaSize(int offset) throws Exception {
		return Register.sizeIndexedLEA + Register.getIndexedOffsetSize(offset);
	}

	private static int leaCycles(int offset) throws Exception {
		return Register.costIndexedLEA + Register.getIndexedOffsetCost(offset);
	}

	/**
	 * the cost (what : 0 bytes, 1 cycles) of giving U back once the writes
	 * leave it at c : the first LEAU's offset changed, or a LEAU of its own
	 * (none when the pattern code is empty and the caller resets U)
	 */
	private static int back(int c, Integer first, boolean restoreU, int what) throws Exception {
		if (first != null) {
			int now = first - c == 0 ? 0 : (what == 0 ? leaSize(first - c) : leaCycles(first - c));
			int was = what == 0 ? leaSize(first) : leaCycles(first);
			return now - was;
		}
		if (c == 0 || !restoreU) {
			return 0;
		}
		return what == 0 ? leaSize(-c) : leaCycles(-c);
	}

	/** an AND is needed when an opaque bit has to end up 0, an OR when one has to end up 1 */
	private static boolean needsAnd(int mask, int value) {
		return (~mask & ~value & 0xff) != 0;
	}

	private static String write(int[] op, int offset) {
		String at = (offset == 0 ? "" : Integer.toString(offset)) + ",U";
		StringBuilder sb = new StringBuilder();
		if (op[1] == 1) {
			sb.append("\tLDA ").append(at);
			if (needsAnd(op[2], op[3])) {
				sb.append(String.format("\n\tANDA #$%02X", op[2] & 0xff));
			}
			if (op[3] != 0) {
				sb.append(String.format("\n\tORA #$%02X", op[3]));
			}
			sb.append("\n\tSTA ").append(at);
		} else {
			sb.append("\tLDD ").append(at);
			if (needsAnd(op[2], op[3])) {
				sb.append(String.format("\n\tANDA #$%02X", op[2] & 0xff));
			}
			if (needsAnd(op[4], op[5])) {
				sb.append(String.format("\n\tANDB #$%02X", op[4] & 0xff));
			}
			if (op[3] != 0) {
				sb.append(String.format("\n\tORA #$%02X", op[3]));
			}
			if (op[5] != 0) {
				sb.append(String.format("\n\tORB #$%02X", op[5]));
			}
			sb.append("\n\tSTD ").append(at);
		}
		return sb.toString();
	}

	private static int writeSize(int[] op, int offset) throws Exception {
		int r = op[1] == 1 ? Register.A : Register.D;
		int size = Register.sizeIndexedLD[r] + Register.sizeIndexedST[r] + 2 * Register.getIndexedOffsetSize(offset);
		size += (needsAnd(op[2], op[3]) ? 2 : 0) + (op[3] != 0 ? 2 : 0);
		if (op[1] == 2) {
			size += (needsAnd(op[4], op[5]) ? 2 : 0) + (op[5] != 0 ? 2 : 0);
		}
		return size;
	}

	private static int writeCycles(int[] op, int offset) throws Exception {
		int r = op[1] == 1 ? Register.A : Register.D;
		int cycles = Register.costIndexedLD[r] + Register.costIndexedST[r] + 2 * Register.getIndexedOffsetCost(offset);
		cycles += (needsAnd(op[2], op[3]) ? 2 : 0) + (op[3] != 0 ? 2 : 0);
		if (op[1] == 2) {
			cycles += (needsAnd(op[4], op[5]) ? 2 : 0) + (op[5] != 0 ? 2 : 0);
		}
		return cycles;
	}

	/** true when the second plane is reached through glb_screen_location_1, U reset */
	private boolean planesByPointer() {
		return !planesByOffset() && !planesByCursor();
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
