package com.widedot.toolbox.graphics.gfxcomp.encoder.onebpp;

import java.io.File;
import java.nio.charset.Charset;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.util.ArrayList;
import java.util.List;

import com.widedot.m6809.util.asm.Register;
import com.widedot.toolbox.graphics.gfxcomp.Image;
import com.widedot.toolbox.graphics.gfxcomp.encoder.Encoder;

import lombok.extern.slf4j.Slf4j;

/**
 * Compiled 1bpp sprite with background backup (the bdraw half of the onebpp
 * pair, selected by {@code <encoder name="bdraw1">}).
 *
 * The emitted routine honours the same contract as the 4bpp bdraw routine :
 * U enters pointing at the destination screen byte, Y at the end of a free
 * background cell range, and U leaves holding the start of the saved
 * background for the erase routine to replay. A single plane is written — no
 * mid-routine plane switch — so the same code draws on RAMA or on RAMB : the
 * plane is selected by the address the caller passes in U, at run time.
 *
 * Each opaque screen byte is drawn read-modify-write so transparent bits keep
 * the background ({@code LDA o,U / PSHS A / ANDA #mask / ORA #imm / STA o,U}).
 * The screen base is pushed last, so the erase routine pops it first and every
 * restore hits the screen, not the cells : popping U last (after the byte
 * restores) would leave the restores pointed at the background cells,
 * spilling past the pool into vectors and code. Fully transparent bytes are
 * skipped on both sides — draw and erase stay paired by construction, since
 * both derive from the same packed box.
 * U never advances : every access is explicitly indexed from the row base, so
 * there is no cursor to lose track of.
 */
@Slf4j
// getX1_offset and siblings keep the Encoder base class names (v1 API)
@SuppressWarnings("PMD.MethodNamingConventions")
public class BdrawGenerator extends Encoder {

	public String name;

	private int x1_offset;
	private int y1_offset;
	private int x_size;
	private int origin; // packed box offset from the canvas reference byte/row (Image.getMonoOrigin)
	private int y_size;

	private int rows;
	private int rowBytes;
	private int[][] imm;

	private List<String> spriteCode = new ArrayList<String>();
	private List<String> spriteECode = new ArrayList<String>();
	private int cyclesSpriteCode;
	private int cyclesSpriteECode;
	private int sizeSpriteCode;
	private int sizeSpriteECode;
	private int eraseDataSize;

	private int cyclesDFrameCode;
	private int sizeDFrameCode;
	private int cyclesEFrameCode;
	private int sizeEFrameCode;

	private Path asmDFile;
	private Path asmEFile;

	public BdrawGenerator(Image img, String destDir) throws Exception {
		name = img.getFullName();
		x1_offset = img.getSubImageX1Offset();
		y1_offset = img.getSubImageY1Offset();
		x_size = img.getSubImageXSize();
		origin = img.getMonoOrigin();
		y_size = img.getSubImageYSize();

		log.debug("\t\t\tImage:" + name);
		log.debug("\t\t\tX1Offset: " + getX1_offset());
		log.debug("\t\t\tY1Offset: " + getY1_offset());
		log.debug("\t\t\tXSize: " + getX_size());
		log.debug("\t\t\tYSize: " + getY_size());

		String asmDir = destDir + "/" + name;
		String asmBckDrawFileName = asmDir + ".asm";
		File file = new File(asmBckDrawFileName);
		file.getParentFile().mkdirs();
		asmDFile = Paths.get(asmBckDrawFileName);

		String asmEraseFileName = asmDir + "_erase.asm";
		asmEFile = Paths.get(asmEraseFileName);

		if (!img.isMonoEmpty()) {
			rows = y_size + 1;
			rowBytes = img.getMonoRowBytes();
			byte[] mono = img.getSubImagePixels(0);
			imm = new int[rows][rowBytes];
			for (int r = 0; r < rows; r++) {
				for (int c = 0; c < rowBytes; c++) {
					imm[r][c] = BitPack.pack(mono, Image.MONO_STRIDE, img.getMonoX0(), img.getMonoY0() + r, c);
				}
			}
		}

		buildDrawCode();
		buildEraseCode();

		// same cell accounting as the 4bpp bdraw routine : the erase stream
		// plus the 12 bytes an IRQ may push on the user stack, in 64 byte cells
		img.nb_cell = (getEraseDataSize() + 12 + 64 - 1) / 64;

		cyclesDFrameCode = getCodeFrameBckDrawStartCycles() + getCodeFrameBckDrawEndCycles();
		sizeDFrameCode = getCodeFrameBckDrawStartSize() + getCodeFrameBckDrawEndSize();
		cyclesEFrameCode = getCodeFrameEraseStartCycles() + getCodeFrameEraseEndCycles();
		sizeEFrameCode = getCodeFrameEraseStartSize() + getCodeFrameEraseEndSize();
	}

	private void buildDrawCode() throws Exception {
		for (int r = 0; r < rows; r++) {
			for (int c = 0; c < rowBytes; c++) {
				int v = imm[r][c];
				if (v == 0) {
					continue;
				}
				int o = r * BitPack.LINE_BYTES + c + origin;
				int mask = (~v) & 0xFF;
				spriteCode.add("\tLDA " + o + ",U");
				spriteCode.add("\tPSHS A");
				spriteCode.add("\tANDA #$" + String.format("%02X", mask));
				spriteCode.add("\tORA #$" + String.format("%02X", v));
				spriteCode.add("\tSTA " + o + ",U");
				cyclesSpriteCode += Register.costIndexedLD[Register.A] + Register.getIndexedOffsetCost(o);
				cyclesSpriteCode += Register.getCostImmediatePULPSH(1);
				cyclesSpriteCode += Register.costImmediateAND[Register.A];
				cyclesSpriteCode += Register.costImmediateOR[Register.A];
				cyclesSpriteCode += Register.costIndexedST[Register.A] + Register.getIndexedOffsetCost(o);
				sizeSpriteCode += Register.sizeIndexedLD[Register.A] + Register.getIndexedOffsetSize(o);
				sizeSpriteCode += Register.sizeImmediatePULPSH;
				sizeSpriteCode += Register.sizeImmediateAND[Register.A];
				sizeSpriteCode += Register.sizeImmediateOR[Register.A];
				sizeSpriteCode += Register.sizeIndexedST[Register.A] + Register.getIndexedOffsetSize(o);
			}
		}
	}

	private void buildEraseCode() throws Exception {
		// the screen base comes back first : every restore below then hits
		// the screen through U, while S walks the cells back up. Popping it
		// last would restore the background over the cells instead, spilling
		// past the pool once offsets exceed it.
		spriteECode.add("\tPULS U");
		cyclesSpriteECode += Register.getCostImmediatePULPSH(2);
		sizeSpriteECode += Register.sizeImmediatePULPSH;
		// mirror of the draw order : the stack top holds the last pushed
		// byte once U is out of the way
		for (int r = rows - 1; r >= 0; r--) {
			for (int c = rowBytes - 1; c >= 0; c--) {
				if (imm[r][c] == 0) {
					continue;
				}
				int o = r * BitPack.LINE_BYTES + c + origin;
				spriteECode.add("\tPULS A");
				spriteECode.add("\tSTA " + o + ",U");
				cyclesSpriteECode += Register.getCostImmediatePULPSH(1);
				cyclesSpriteECode += Register.costIndexedST[Register.A] + Register.getIndexedOffsetCost(o);
				sizeSpriteECode += Register.sizeImmediatePULPSH;
				sizeSpriteECode += Register.sizeIndexedST[Register.A] + Register.getIndexedOffsetSize(o);
				eraseDataSize += 1;
			}
		}
		eraseDataSize += 2; // the screen base pushed on exit
	}

	// the toolchain signals build errors with plain Exceptions (see Encoder and Image)
	@SuppressWarnings("PMD.AvoidThrowingRawExceptionTypes")
	public void generateCode() {
		try {
			Files.deleteIfExists(asmDFile);
			Files.createFile(asmDFile);

			Files.write(asmDFile, getCodeFrameBckDrawStart(), Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			Files.write(asmDFile, spriteCode, Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			Files.write(asmDFile, getCodeFrameBckDrawEnd(), Charset.forName("UTF-8"), StandardOpenOption.APPEND);

			log.debug("\t\t\tSize: " + getDSize());
			log.debug("\t\t\tCycles: " + getDCycles());

			if (getDSize() > 16384) {
				throw new Exception("\t\t\t" + " Le code généré (" + getDSize() + " octets) dépasse la taille d'une page",
						new Exception("Prérequis."));
			}

			Files.deleteIfExists(asmEFile);
			Files.createFile(asmEFile);

			List<String> dataSize = new ArrayList<String>();
			dataSize.add(String.format(name + "_datasize equ $%1$04X", getEraseDataSize() & 0xFFFF));

			Files.write(asmEFile, getCodeFrameEraseStart(), Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			Files.write(asmEFile, spriteECode, Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			Files.write(asmEFile, getCodeFrameEraseEnd(), Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			Files.write(asmEFile, dataSize, Charset.forName("UTF-8"), StandardOpenOption.APPEND);

			log.debug("\t\t\tE Size: " + getESize());
			log.debug("\t\t\tE Cycles: " + getECycles());

			if (getESize() > 16384) {
				throw new Exception("\t\t\t" + " Le code généré (" + getESize() + " octets) dépasse la taille d'une page",
						new Exception("Prérequis."));
			}
		} catch (Exception e) {
			throw new RuntimeException(e);
		}
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
		cycles += Register.costIndexedLEA + Register.getIndexedOffsetCost(0);
		return cycles;
	}

	public int getCodeFrameBckDrawStartSize() throws Exception {
		int size = 0;
		size += Register.sizeExtendedST[Register.S];
		size += Register.sizeIndexedLEA + Register.getIndexedOffsetSize(0);
		return size;
	}

	public List<String> getCodeFrameBckDrawEnd() {
		List<String> asm = new ArrayList<String>();
		asm.add("\tPSHS U");
		asm.add("\tLEAU ,S");
		asm.add("\tLDS glb_register_s");
		asm.add("\tRTS\n");
		return asm;
	}

	public int getCodeFrameBckDrawEndCycles() {
		int cycles = 0;
		cycles += Register.getCostImmediatePULPSH(2);
		cycles += Register.costIndexedLEA;
		cycles += Register.costExtendedLD[Register.S];
		cycles += 5; // RTS
		return cycles;
	}

	public int getCodeFrameBckDrawEndSize() {
		int size = 0;
		size += Register.sizeImmediatePULPSH;
		size += Register.sizeIndexedLEA;
		size += Register.sizeExtendedLD[Register.S];
		size += 1; // RTS
		return size;
	}

	public List<String> getCodeFrameEraseStart() {
		List<String> asm = new ArrayList<String>();
		asm.add("\tINCLUDE \"./engine/constants.asm\"");
		asm.add("\tOPT C,CT");
		asm.add("adr_" + name + "_erase");
		asm.add("\tSTS glb_register_s\n");
		asm.add("\tLEAS ,U");
		return asm;
	}

	public int getCodeFrameEraseStartCycles() throws Exception {
		int cycles = 0;
		cycles += Register.costExtendedST[Register.S];
		cycles += Register.costIndexedLEA + Register.getIndexedOffsetCost(0);
		return cycles;
	}

	public int getCodeFrameEraseStartSize() throws Exception {
		int size = 0;
		size += Register.sizeExtendedST[Register.S];
		size += Register.sizeIndexedLEA + Register.getIndexedOffsetSize(0);
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
		return cyclesDFrameCode + cyclesSpriteCode;
	}

	public int getDSize() {
		return sizeDFrameCode + sizeSpriteCode;
	}

	public int getECycles() {
		return cyclesEFrameCode + cyclesSpriteECode;
	}

	public int getESize() {
		return sizeEFrameCode + sizeSpriteECode;
	}

	public int getEraseDataSize() {
		return eraseDataSize;
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
