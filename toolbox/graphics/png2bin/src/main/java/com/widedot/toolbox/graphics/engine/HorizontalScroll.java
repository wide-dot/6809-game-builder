package com.widedot.toolbox.graphics.engine;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import lombok.extern.slf4j.Slf4j;

/**
 * Horizontal Scroll code buffer generator (looping 160px band, BM16).
 *
 * Input: one plane binary produced by png2bin (40 bytes per line, top-down),
 * from a 160px wide, H lines tall band image that loops on itself in x.
 *
 * Output: a code buffer (stack blast, written backward like VerticalScroll)
 * with a runtime-variable entry point (horizontal rotation) and a fixed
 * exit point:
 *
 *   [ ENTRY LINE ]  bottom line of the band, 10 uniform chunks of
 *                   4 data bytes: ldd # / ldx # / pshs d,x (8 code bytes)
 *                   -> runtime entry at chunk h = 16*h px rotation
 *   [ BODY ]        lines H-2..0 (bottom to top), 5 chunks of 8 data
 *                   bytes per line: ldd/ldx/ldy/ldu/pshs d,x,y,u
 *   [ GUARD LINE ]  extra line above the band, solid color (parameter),
 *                   10 uniform chunks of 4 data bytes
 *   [ PAD ]         3 bytes, patched with the exit JMP by the driver
 *
 * Rotating the entry by h chunks leaves the top-left 4*h bytes of the
 * rendered area unwritten (the "wrapped" bytes are skipped): they land in
 * the solid color guard line, and the driver refills them (guard color)
 * after each run, so no artefact remains. Total rendered height is H+1.
 *
 * Fine scroll (4px and 2px steps) is handled at runtime by offsetting S
 * and swapping RAMA/RAMB destinations, no code variant needed.
 * See engine/graphics/tilemap/hscroll/ (thomson-to8-game-engine repo).
 */
@Slf4j
public class HorizontalScroll {

	private static final int LINE_BYTES = 40;       // one plane line of a 160px BM16 band
	private static final int ENTRY_CHUNK_DATA = 4;  // data bytes per entry/guard chunk
	private static final int ENTRY_CHUNK_CODE = 8;  // code bytes per entry/guard chunk
	private static final int BODY_CHUNK_DATA = 8;   // data bytes per body chunk
	private static final int BODY_CHUNK_CODE = 15;  // code bytes per body chunk
	private static final int PAD = 3;               // exit JMP location

	public HorizontalScroll(String fileName, int guardColor){

		log.info("Engine horizontal scroll generator");
		log.info("Load "+fileName+ " file ...");

		try {

			byte ldd = (byte) 0xCC;
			byte ldx = (byte) 0x8E;
			byte[] ldy = {(byte) 0x10, (byte) 0x8E};
			byte ldu = (byte) 0xCE;
			byte[] pshsDXYU = {(byte) 0x34, (byte) 0x76};
			byte[] pshsDX = {(byte) 0x34, (byte) 0x16};

			if (guardColor < 0 || guardColor > 15) {
				throw new Exception("guard color must be a 4 bit pixel value (0-15)");
			}
			byte guard = (byte) ((guardColor << 4) | guardColor); // both pixels of the byte

			Path path = Paths.get(fileName);
			byte[] raw = Files.readAllBytes(path);

			if (raw.length % LINE_BYTES != 0) {
				throw new Exception("input size "+raw.length+" is not a multiple of "+LINE_BYTES+" bytes (160px band plane expected)");
			}
			int height = raw.length / LINE_BYTES;
			if (height < 2) {
				throw new Exception("band height must be at least 2 lines");
			}

			int lineChunks = LINE_BYTES/ENTRY_CHUNK_DATA;                            // 10
			int entrySize  = lineChunks * ENTRY_CHUNK_CODE;                          // 80
			int bodySize   = (LINE_BYTES/BODY_CHUNK_DATA) * (height-1) * BODY_CHUNK_CODE; // 75*(H-1)
			int exitOffset = entrySize + bodySize;
			byte[] out = new byte[exitOffset + entrySize + PAD];
			int k = 0;

			// entry line: bottom line of the band, chunks from right to left
			int i = raw.length - ENTRY_CHUNK_DATA;
			while (i >= raw.length - LINE_BYTES) {
				out[k++] = ldd;
				out[k++] = raw[i];
				out[k++] = raw[i+1];
				out[k++] = ldx;
				out[k++] = raw[i+2];
				out[k++] = raw[i+3];
				out[k++] = pshsDX[0];
				out[k++] = pshsDX[1];
				i = i - ENTRY_CHUNK_DATA;
			}

			// body: lines H-2..0, chunks from right to left, bottom to top
			i = raw.length - LINE_BYTES - BODY_CHUNK_DATA;
			while (i >= 0) {
				out[k++] = ldd;
				out[k++] = raw[i];
				out[k++] = raw[i+1];
				out[k++] = ldx;
				out[k++] = raw[i+2];
				out[k++] = raw[i+3];
				out[k++] = ldy[0];
				out[k++] = ldy[1];
				out[k++] = raw[i+4];
				out[k++] = raw[i+5];
				out[k++] = ldu;
				out[k++] = raw[i+6];
				out[k++] = raw[i+7];
				out[k++] = pshsDXYU[0];
				out[k++] = pshsDXYU[1];
				i = i - BODY_CHUNK_DATA;
			}

			// guard line: solid color, drawn above the band (uniform chunks:
			// the unwritten hole left by the entry rotation lands here)
			for (int j = 0; j < lineChunks; j++) {
				out[k++] = ldd;
				out[k++] = guard;
				out[k++] = guard;
				out[k++] = ldx;
				out[k++] = guard;
				out[k++] = guard;
				out[k++] = pshsDX[0];
				out[k++] = pshsDX[1];
			}
			// pad: exit JMP location (always patched by the driver before run)
			k += PAD;

			Path outpath = Paths.get(fileName+".hscroll");
			Files.write(outpath, out);

			// metadata equates for the game project
			int guardWord = ((guard & 0xFF) << 8) | (guard & 0xFF);
			String eol = System.lineSeparator();
			StringBuilder equ = new StringBuilder();
			equ.append("; generated by png2bin -hs from "+path.getFileName()+eol);
			equ.append("hscroll.band.HEIGHT           equ "+(height+1)+" ; band height + guard line"+eol);
			equ.append("hscroll.band.ENTRY_CHUNK_SIZE equ "+ENTRY_CHUNK_CODE+eol);
			equ.append("hscroll.band.EXIT_OFFSET      equ "+exitOffset+" ; guard line offset"+eol);
			equ.append("hscroll.band.CODE_SIZE        equ "+out.length+eol);
			equ.append("hscroll.band.GUARD            equ $"+String.format("%04X", guardWord)+" ; guard color word"+eol);
			Path equpath = Paths.get(fileName+".hscroll.equ");
			Files.write(equpath, equ.toString().getBytes(StandardCharsets.UTF_8));

			log.info("height: "+height+"+1 lines, code size: "+out.length+" bytes, exit offset: "+exitOffset+", guard color: "+guardColor);

		} catch (Exception e) {
			e.printStackTrace();
			log.error(e.toString());
		}
		log.info("done.");
	}

}
