package com.widedot.toolbox.graphics.engine;

/**
 * The 16 000 bytes engine/graphics/draw/DrawFullscreenImage.asm copies : a
 * 160x200 BM16 picture, climbing the screen. The routine pulls 7 bytes with
 * PULU (U going up through the data) and pushes them with PSHS (S going down
 * from the end of a bank), so the data holds each bank's 7-byte blocks from
 * the last to the first, a block's bytes in screen order : the $C000 bank
 * first (png2bin's plane 0, pixels 0-1 of each four), then the $A000 bank.
 * 8 000 is not a multiple of 7 : each bank ends with the 6 bytes at its start.
 *
 * v1 : fr.bento8.to8.image.PngToBottomUpB16Bin, the same bytes.
 */
public final class FullscreenImage {

	public static final int BANK = 8000;
	private static final int BLOCK = 7;     // pulu a,b,dp,x,y

	private FullscreenImage() {
	}

	/** the two planes of a 160x200 BM16 picture (png2bin's, 8 000 bytes each) as the routine's data */
	public static byte[] of(byte[] plane0, byte[] plane1) {
		byte[] out = new byte[2 * BANK];
		climb(plane0, out, 0);
		climb(plane1, out, BANK);
		return out;
	}

	private static void climb(byte[] plane, byte[] out, int start) {
		int o = start;
		int top = BANK;
		while (top >= BLOCK) {
			System.arraycopy(plane, top - BLOCK, out, o, BLOCK);
			o += BLOCK;
			top -= BLOCK;
		}
		System.arraycopy(plane, 0, out, o, top);
	}
}
