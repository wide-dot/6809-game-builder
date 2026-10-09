package com.widedot.toolbox.graphics.gfxcomp.transformer.pairs;

import java.awt.image.BufferedImage;
import java.awt.image.IndexColorModel;
import java.awt.image.WritableRaster;

/**
 * The bm4s source transform : a 320 pixel picture in 4 colours becomes the
 * 160 pixel BM16 picture that draws it in the $41 mode.
 *
 * In $41 a screen byte holds four 2 bit pixels, leftmost in bits 7-6, and the
 * RAMA byte of an address shows the four pixels to the left of its RAMB byte :
 * the byte layout of BM16, whose bytes hold two 4 bit pixels. A BM16 pixel
 * therefore covers two $41 pixels, and the pair (left, right) is the BM16
 * colour (left << 2) | right. The encoders, the imageset and the sprite
 * runtime then work unchanged.
 *
 * Source convention : index 0 is transparent, 1 to 4 are the colours 0 to 3
 * (the palette entries the mode shows). Packed convention, the encoders' :
 * index 0 transparent, 1 to 16 the BM16 colour + 1. BM16 transparency goes by
 * pixel, so a pair is transparent as a whole or not at all : a half
 * transparent pair cannot be drawn and is refused, as is an odd width.
 */
public final class PixelPairs {

	/** the colours a bm4s source may use, after the transparent index 0 */
	public static final int COLOURS = 4;

	private PixelPairs() {
	}

	/** the packed picture of a 320 convention source ; file names the source in errors */
	// the toolchain signals build errors with plain Exceptions
	@SuppressWarnings("PMD.AvoidThrowingRawExceptionTypes")
	public static BufferedImage pack(BufferedImage src, String file) throws Exception {
		int width = src.getWidth();
		int height = src.getHeight();
		if (width % 2 != 0) {
			throw new Exception(file + " is " + width + " pixels wide : a bm4s picture goes by pixel pairs,"
					+ " its width must be even");
		}
		if (src.getColorModel().getPixelSize() != 8) {
			throw new Exception("unsupported file format for " + file + ", pixel size: "
					+ src.getColorModel().getPixelSize() + " (should be 8).");
		}
		BufferedImage dst = new BufferedImage(width / 2, height, BufferedImage.TYPE_BYTE_INDEXED, packedModel());
		WritableRaster in = src.getRaster();
		WritableRaster out = dst.getRaster();
		for (int y = 0; y < height; y++) {
			for (int x = 0; x < width; x += 2) {
				out.setSample(x / 2, y, 0, pair(file, x, y, in.getSample(x, y, 0), in.getSample(x + 1, y, 0)));
			}
		}
		return dst;
	}

	/** the packed index of the pair at (x, y), 0 when both are transparent */
	// the toolchain signals build errors with plain Exceptions
	@SuppressWarnings("PMD.AvoidThrowingRawExceptionTypes")
	private static int pair(String file, int x, int y, int left, int right) throws Exception {
		if (left > COLOURS || right > COLOURS) {
			throw new Exception(file + " : pixel (" + (left > COLOURS ? x : x + 1) + "," + y + ") has index "
					+ Math.max(left, right) + ", a bm4s picture has " + COLOURS
					+ " colours (indexes 1 to " + COLOURS + ", 0 transparent)");
		}
		if ((left == 0) != (right == 0)) {
			throw new Exception(file + " : the pixel pair (" + x + "," + y + ")-(" + (x + 1) + "," + y
					+ ") is half transparent : in bm4s transparency goes by pixel pairs");
		}
		return left == 0 ? 0 : ((left - 1) << 2 | (right - 1)) + 1;
	}

	/** an 8 bit indexed model : 0 transparent, 1 to 16 a grey ramp (the BM16 colour + 1) */
	private static IndexColorModel packedModel() {
		byte[] r = new byte[17];
		byte[] g = new byte[17];
		byte[] b = new byte[17];
		for (int i = 1; i < 17; i++) {
			r[i] = (byte) ((i - 1) * 17);
			g[i] = r[i];
			b[i] = r[i];
		}
		return new IndexColorModel(8, 17, r, g, b, 0);
	}
}
