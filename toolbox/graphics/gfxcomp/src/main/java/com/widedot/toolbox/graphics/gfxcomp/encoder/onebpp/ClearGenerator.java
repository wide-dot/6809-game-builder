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
 * Compiled 1bpp sprite without background backup, with compiled clear-erase
 * (selected by {@code <encoder name="clear1">}).
 *
 * For planes that hold sprites only : the background is empty by design, so
 * erasing restores nothing, it clears. The draw half is the bdraw draw
 * without the push ({@code LDA o,U / ANDA #mask / ORA #imm / STA o,U},
 * {@code LDA #$FF / STA o,U} for full bytes) ; the erase half clears
 * exactly the drawn bytes ({@code CLR o,U}), in any order — no stack, no
 * pairing constraint. U enters pointing at the destination screen byte on
 * both sides ; Y is unused, no background cell is allocated, and
 * {@code eraseDataSize} is 0.
 *
 * Like its siblings the code is plane-agnostic : RAMA or RAMB is selected
 * by the address the caller passes in U, at run time. The variant answers
 * to B in the imageset (same subset layout as bdraw1) ; clear1 and bdraw1
 * must not mix on one image.
 */
@Slf4j
public class ClearGenerator extends Encoder {

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

	private int cyclesDFrameCode;
	private int sizeDFrameCode;
	private int cyclesEFrameCode;
	private int sizeEFrameCode;

	private String asmDrawFileName;
	private String asmEraseFileName;
	private Path asmDFile;
	private Path asmEFile;

	public ClearGenerator(Image img, String destDir) throws Exception {
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

		destDir += "/" + name;
		asmDrawFileName = destDir + ".asm";
		File file = new File(asmDrawFileName);
		file.getParentFile().mkdirs();
		asmDFile = Paths.get(asmDrawFileName);

		asmEraseFileName = destDir + "_erase.asm";
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

		// nothing is saved, nothing is allocated : the runtime skips the
		// background cells entirely for this variant
		img.nb_cell = 0;

		cyclesDFrameCode = getCodeFrameDrawStartCycles() + getCodeFrameDrawEndCycles();
		sizeDFrameCode = getCodeFrameDrawStartSize() + getCodeFrameDrawEndSize();
		cyclesEFrameCode = getCodeFrameEraseStartCycles() + getCodeFrameEraseEndCycles();
		sizeEFrameCode = getCodeFrameEraseStartSize() + getCodeFrameEraseEndSize();
	}

	private void buildDrawCode() throws Exception {
		RowCode rc = RowCode.draw(imm, rows, rowBytes, origin);
		spriteCode.addAll(rc.code);
		cyclesSpriteCode += rc.cycles;
		sizeSpriteCode += rc.size;
	}

	private void buildEraseCode() throws Exception {
		// zero exactly the drawn bytes : transparent holes are skipped on
		// both sides, so draw and erase stay paired by construction. Order
		// is free, no stack discipline to mirror.
		RowCode rc = RowCode.clear(imm, rows, rowBytes, origin);
		spriteECode.addAll(rc.code);
		cyclesSpriteECode += rc.cycles;
		sizeSpriteECode += rc.size;
	}

	public void generateCode() {
		try {
			Files.deleteIfExists(asmDFile);
			Files.createFile(asmDFile);

			Files.write(asmDFile, getCodeFrameDrawStart(), Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			Files.write(asmDFile, spriteCode, Charset.forName("UTF-8"), StandardOpenOption.APPEND);
			Files.write(asmDFile, getCodeFrameDrawEnd(), Charset.forName("UTF-8"), StandardOpenOption.APPEND);

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

	public List<String> getCodeFrameDrawStart() {
		List<String> asm = new ArrayList<String>();
		asm.add("\tINCLUDE \"./engine/constants.asm\"");
		asm.add("\tOPT C,CT");
		asm.add("adr_" + name);
		return asm;
	}

	public int getCodeFrameDrawStartCycles() throws Exception {
		return 0;
	}

	public int getCodeFrameDrawStartSize() throws Exception {
		return 0;
	}

	public List<String> getCodeFrameDrawEnd() {
		List<String> asm = new ArrayList<String>();
		asm.add("\tRTS\n");
		return asm;
	}

	public int getCodeFrameDrawEndCycles() {
		return 5; // RTS
	}

	public int getCodeFrameDrawEndSize() {
		return 1; // RTS
	}

	public List<String> getCodeFrameEraseStart() {
		List<String> asm = new ArrayList<String>();
		asm.add("\tINCLUDE \"./engine/constants.asm\"");
		asm.add("\tOPT C,CT");
		asm.add("adr_" + name + "_erase");
		return asm;
	}

	public int getCodeFrameEraseStartCycles() throws Exception {
		return 0;
	}

	public int getCodeFrameEraseStartSize() throws Exception {
		return 0;
	}

	public List<String> getCodeFrameEraseEnd() {
		List<String> asm = new ArrayList<String>();
		asm.add("\tRTS\n");
		return asm;
	}

	public int getCodeFrameEraseEndCycles() {
		return 5; // RTS
	}

	public int getCodeFrameEraseEndSize() {
		return 1; // RTS
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
		return 0;
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
