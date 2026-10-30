package com.widedot.toolbox.graphics.spritestream;

import java.awt.image.BufferedImage;
import java.awt.image.Raster;
import java.io.File;

import javax.imageio.ImageIO;

/**
 * A picture as the screen bytes it draws, in bm4s : an 8 bit indexed PNG,
 * index 0 transparent, 1 to 4 the mode's colours 0 to 3, one PNG pixel a
 * screen pixel, column 0 at pixel 0 of a screen byte. A screen byte holds 4
 * pixels, the leftmost in bits 7-6 ; consecutive screen bytes alternate
 * between the two video planes. A width that is not a multiple of 4 is
 * completed with transparent pixels.
 *
 * Each byte is {mask, data} : the mask's bits 11 keep the screen pixel, data
 * holds the colour of the opaque pixels (0 where transparent), so a draw is
 * screen = (screen AND mask) OR data.
 */
final class Picture {

	final String file;
	final int width;
	final int height;
	/** bytes[row][j] = {mask, data} */
	final int[][][] bytes;
	/** pixels[row][x] : -1 transparent, else 0-3 */
	final int[][] pixels;

	Picture(String file, int[][] pixels) {
		this.file = file;
		this.pixels = pixels;
		this.height = pixels.length;
		this.width = height == 0 ? 0 : pixels[0].length;
		int nb = (width + 3) / 4;
		bytes = new int[height][nb][];
		for (int y = 0; y < height; y++) {
			for (int j = 0; j < nb; j++) {
				int mask = 0, data = 0;
				for (int k = 0; k < 4; k++) {
					int x = 4 * j + k;
					int shift = 6 - 2 * k;
					int p = x < width ? pixels[y][x] : -1;
					if (p < 0) {
						mask |= 3 << shift;
					} else {
						data |= p << shift;
					}
				}
				bytes[y][j] = new int[] { mask, data };
			}
		}
	}

	static Picture read(String file) throws Exception {
		BufferedImage im = ImageIO.read(new File(file));
		if (im == null) {
			throw new Exception(file + " : not a picture");
		}
		if (!(im.getColorModel() instanceof java.awt.image.IndexColorModel)) {
			throw new Exception(file + " : an indexed PNG is expected (index 0 transparent, 1 to 4 the colours)");
		}
		Raster r = im.getRaster();
		int[][] px = new int[im.getHeight()][im.getWidth()];
		for (int y = 0; y < im.getHeight(); y++) {
			for (int x = 0; x < im.getWidth(); x++) {
				int v = r.getSample(x, y, 0);
				if (v > 4) {
					throw new Exception(file + " : pixel (" + x + "," + y + ") has index " + v
							+ ", a bm4s picture uses 0 (transparent) to 4");
				}
				px[y][x] = v - 1;
			}
		}
		return new Picture(file, px);
	}

	/** screen bytes of a row */
	int boxBytes() {
		return bytes.length == 0 ? 0 : bytes[0].length;
	}

	/** the same pixels mirrored left to right : the bytes reversed, each byte's pixels reversed */
	static int[][][] mirror(int[][][] vb) {
		int[][][] out = new int[vb.length][][];
		for (int y = 0; y < vb.length; y++) {
			int n = vb[y].length;
			out[y] = new int[n][];
			for (int j = 0; j < n; j++) {
				int[] b = vb[y][n - 1 - j];
				out[y][j] = new int[] { rev(b[0]), rev(b[1]) };
			}
		}
		return out;
	}

	/** the 4 two-bit pixels of a byte in reverse order */
	static int rev(int b) {
		return ((b & 3) << 6) | ((b & 0x0C) << 2) | ((b & 0x30) >> 2) | ((b & 0xC0) >> 6);
	}

	/** true when this picture is base moved right by 2 pixels (the next 2 pixel step) */
	boolean isShiftOf(Picture base) {
		if (height != base.height || width != base.width + 2) {
			return false;
		}
		for (int y = 0; y < height; y++) {
			if (pixels[y][0] >= 0 || pixels[y][1] >= 0) {
				return false;
			}
			for (int x = 0; x < base.width; x++) {
				if (pixels[y][x + 2] != base.pixels[y][x]) {
					return false;
				}
			}
		}
		return true;
	}
}
