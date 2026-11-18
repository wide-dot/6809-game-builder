package com.widedot.toolbox.graphics.raycast;

import java.awt.image.BufferedImage;
import java.awt.image.IndexColorModel;
import java.io.File;

import javax.imageio.ImageIO;

/**
 * Wall textures : an indexed picture, 64 pixels high, a texture every 64
 * pixels of its width, as texture columns — texels column-major, 64 bytes a
 * column, both nibbles of a byte the colour (a byte column of the screen is
 * 2 BM16 pixels of the same colour).
 */
// the toolchain signals build errors with plain Exceptions
@SuppressWarnings("PMD.AvoidThrowingRawExceptionTypes")
final class TextureEncoder {

	/** the textures' colour indexes : [texture][column][row] */
	final int[][][] texels;

	TextureEncoder(int[][][] texels) {
		this.texels = texels;
	}

	static TextureEncoder read(String file) throws Exception {
		BufferedImage img = ImageIO.read(new File(file));
		if (img == null) {
			throw new Exception(file + " is not a picture");
		}
		if (!(img.getColorModel() instanceof IndexColorModel)) {
			throw new Exception(file + " is not an indexed picture (16 colours at most)");
		}
		int t = Geometry.TEX;
		if (img.getHeight() != t || img.getWidth() == 0 || img.getWidth() % t != 0) {
			throw new Exception(file + " is " + img.getWidth() + "x" + img.getHeight() + " : textures are " + t + "x" + t
					+ ", side by side");
		}
		int[][][] tex = new int[img.getWidth() / t][t][t];
		for (int n = 0; n < tex.length; n++) {
			for (int x = 0; x < t; x++) {
				for (int y = 0; y < t; y++) {
					int c = img.getRaster().getSample(n * t + x, y, 0);
					if (c > 15) {
						throw new Exception(file + " uses colour " + c + " at (" + (n * t + x) + "," + y + ") : 0 to 15");
					}
					tex[n][x][y] = c;
				}
			}
		}
		return new TextureEncoder(tex);
	}

	int count() {
		return texels.length;
	}

	/** the textures' bytes, a texture after the other */
	byte[] bytes() {
		int t = Geometry.TEX;
		byte[] out = new byte[count() * t * t];
		for (int n = 0; n < count(); n++) {
			for (int x = 0; x < t; x++) {
				for (int y = 0; y < t; y++) {
					out[(n * t + x) * t + y] = (byte) (texels[n][x][y] * 0x11);
				}
			}
		}
		return out;
	}
}
