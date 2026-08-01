package com.widedot.toolbox.graphics.gfxcomp.transformer.shift;

import com.widedot.toolbox.graphics.gfxcomp.transformer.PlaneTransform;

/**
 * Pre-shifted variants : the image is rendered one pixel to the right, so an
 * odd screen position costs nothing at run time.
 *
 * This happens in screen space, on the interlaced planes, not on the source
 * image. The two planes hold the even and the odd pixels of a line, so moving
 * everything across by one means walking data out of one plane into the other
 * with a carry into the next byte. A translate on the source PNG is a
 * different operation: it would measure the geometry on the shifted image,
 * where the imageset needs every variant of a mirror group to declare the
 * geometry of the unshifted one, and it would drop the pixel leaving the line
 * instead of wrapping it.
 *
 * Only a one pixel shift is rendered. Beyond that the image lands on the same
 * plane again, which is a byte offset the drawing code applies itself.
 */
public class Shift implements PlaneTransform {

	// shift types
	public static final String PREFIX  = "shift";
	public static final String SHIFT_0 = PREFIX+"0";
	public static final String SHIFT_1 = PREFIX+"1";
	public static final String SHIFT_2 = PREFIX+"2";
	public static final String SHIFT_3 = PREFIX+"3";
	public static final String SHIFT_4 = PREFIX+"4";
	public static final String SHIFT_5 = PREFIX+"5";
	public static final String SHIFT_6 = PREFIX+"6";
	public static final String SHIFT_7 = PREFIX+"7";

	/** bytes one padded line takes in one plane */
	private static final int LINE = 80;

	private static final Shift onePixel = new Shift();

	public static void transform(byte[][] pixels, byte[][] data, int height, int shift) throws Exception {
		if (shift == 0) {
			return;
		}
		if (shift != 1) {
			throw new Exception("shift " + shift + " : only a one pixel pre-shift is rendered, "
			                  + "a wider one is a byte offset the drawing code applies itself");
		}
		onePixel.apply(pixels, data, height);
	}

	@Override
	public void apply(byte[][] pixels, byte[][] data, int height) {
		byte pixelSave = 0;
		byte dataSave = 0;

		// shift the image one pixel to the right, line by line
		for (int y = 0; y < height; y++) {
			for (int x = LINE-1; x >= 1; x -= 2) {
				if (x == LINE-1) {
					// the pixel leaving the line comes back at its start
					pixelSave = pixels[1][x + (LINE * y)];
					dataSave = data[1][x + (LINE * y)];
				} else {
					pixels[0][(x + 1) + (LINE * y)] = pixels[1][x + (LINE * y)];
					data[0][(x + 1) + (LINE * y)] = data[1][x + (LINE * y)];
				}

				pixels[1][x + (LINE * y)] = pixels[1][(x - 1) + (LINE * y)];
				data[1][x + (LINE * y)] = data[1][(x - 1) + (LINE * y)];

				pixels[1][(x - 1) + (LINE * y)] = pixels[0][x + (LINE * y)];
				data[1][(x - 1) + (LINE * y)] = data[0][x + (LINE * y)];

				pixels[0][x + (LINE * y)] = pixels[0][(x - 1) + (LINE * y)];
				data[0][x + (LINE * y)] = data[0][(x - 1) + (LINE * y)];

				if (x == 1) {
					pixels[0][0 + (LINE * y)] = pixelSave;
					data[0][0 + (LINE * y)] = dataSave;
				}
			}
		}
	}
}
