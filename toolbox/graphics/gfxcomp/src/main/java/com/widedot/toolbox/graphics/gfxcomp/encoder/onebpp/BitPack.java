package com.widedot.toolbox.graphics.gfxcomp.encoder.onebpp;

/**
 * Bit packing for the 1bpp encoders (draw1, bdraw1).
 *
 * A $26 plane holds 320 consecutive pixels per line, 8 pixels per byte, bit 7
 * first : the leftmost pixel of a byte is its most significant bit. A set bit
 * is ink, a clear bit is transparent (the background shows through an ORA).
 */
final class BitPack {

	/** screen bytes of one $26 plane line */
	static final int LINE_BYTES = 40;

	private BitPack() {
	}

	/** screen bytes of a trimmed box row, trailing transparent bits included */
	static int rowBytes(int boxWidthPx) {
		return (boxWidthPx + 7) / 8;
	}

	/**
	 * Pack 8 source pixels into one screen byte, bit 7 first. Pixels past the
	 * trimmed box (the last byte of a row whose width is not a multiple of 8)
	 * read the zeroed area around the box, so they pack as transparent.
	 */
	static int pack(byte[] mono, int stride, int x0, int y, int col) {
		int v = 0;
		for (int b = 0; b < 8; b++) {
			if (mono[y * stride + x0 + col * 8 + b] != 0) {
				v |= 0x80 >> b;
			}
		}
		return v;
	}
}
