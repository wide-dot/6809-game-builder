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
 * Compiled 1bpp sprite without background backup (the draw half of the
 * onebpp pair, selected by {@code <encoder name="draw1">}).
 *
 * Same code shapes as {@link BdrawGenerator} minus the backup : U enters
 * pointing at the destination screen byte and the routine only writes. Fully
 * transparent bytes are skipped outright — U never advances, every access is
 * explicitly indexed — so sparse sprites cost nothing for their holes. Like
 * its bdraw sibling the code is plane-agnostic : RAMA or RAMB is selected by
 * the address the caller passes in U.
 */
@Slf4j
// getX1_offset and siblings keep the Encoder base class names (v1 API)
@SuppressWarnings("PMD.MethodNamingConventions")
public class DrawGenerator extends Encoder {

	public String name;

	private int x1_offset;
	private int y1_offset;
	private int x_size;
	private int y_size;

	private List<String> spriteCode = new ArrayList<String>();
	private int cyclesSpriteCode;
	private int sizeSpriteCode;

	private int cyclesDFrameCode;
	private int sizeDFrameCode;

	private Path asmDFile;

	public DrawGenerator(Image img, String destDir) throws Exception {
		name = img.getFullName();
		x1_offset = img.getSubImageX1Offset();
		y1_offset = img.getSubImageY1Offset();
		x_size = img.getSubImageXSize();
		int origin = img.getMonoOrigin();
		y_size = img.getSubImageYSize();

		log.debug("\t\t\tImage:" + name);
		log.debug("\t\t\tX1Offset: " + getX1_offset());
		log.debug("\t\t\tY1Offset: " + getY1_offset());
		log.debug("\t\t\tXSize: " + getX_size());
		log.debug("\t\t\tYSize: " + getY_size());

		String asmDir = destDir + "/" + name;
		String asmDrawFileName = asmDir + ".asm";
		File file = new File(asmDrawFileName);
		file.getParentFile().mkdirs();
		asmDFile = Paths.get(asmDrawFileName);

		if (!img.isMonoEmpty()) {
			int rows = y_size + 1;
			int rowBytes = img.getMonoRowBytes();
			byte[] mono = img.getSubImagePixels(0);
			int[][] imm = new int[rows][rowBytes];
			for (int r = 0; r < rows; r++) {
				for (int c = 0; c < rowBytes; c++) {
					imm[r][c] = BitPack.pack(mono, Image.MONO_STRIDE, img.getMonoX0(), img.getMonoY0() + r, c);
				}
			}
			RowCode rc = RowCode.draw(imm, rows, rowBytes, origin);
			spriteCode.addAll(rc.code);
			cyclesSpriteCode += rc.cycles;
			sizeSpriteCode += rc.size;
		}

		cyclesDFrameCode = getCodeFrameDrawEndCycles();
		sizeDFrameCode = getCodeFrameDrawEndSize();
	}

	// the toolchain signals build errors with plain Exceptions (see Encoder and Image)
	@SuppressWarnings("PMD.AvoidThrowingRawExceptionTypes")
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

	public int getDCycles() {
		return cyclesDFrameCode + cyclesSpriteCode;
	}

	public int getDSize() {
		return sizeDFrameCode + sizeSpriteCode;
	}

	public int getX_offset() {
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

	public int getEraseDataSize() {
		return 0;
	}
}
