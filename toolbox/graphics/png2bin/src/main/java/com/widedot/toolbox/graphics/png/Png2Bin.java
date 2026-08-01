package com.widedot.toolbox.graphics.png;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

import com.widedot.m6809.util.FileUtil;
import com.widedot.toolbox.graphics.engine.HorizontalScroll;
import com.widedot.toolbox.graphics.engine.VerticalScroll;
import com.widedot.toolbox.graphics.engine.VerticalScrollTile;

import lombok.extern.slf4j.Slf4j;

/**
 * Indexed PNG to video memory binary.
 *
 * The conversion is described by a handful of numbers that say how a pixel is
 * laid out in memory — how many bits of it live in one plane, how many bits
 * are written before moving to the next plane, how many planes there are, and
 * how wide a line is. Those numbers are what makes the same code serve a
 * Thomson bitmap mode and a CoCo3 one.
 *
 *   Thomson MO/TO
 *     t0  320x200x1  : linear 1, planar 0, line 40, planes 1, depth 1
 *     t1  320x200x4  : linear 1, planar 1, line 40, planes 2, depth 2
 *     t1s 320x200x4  : linear 2, planar 8, line 40, planes 2, depth 2
 *     t2  640x200x1  : linear 1, planar 8, line 40, planes 2, depth 1
 *     t3  160x200x16 : linear 4, planar 8, line 40, planes 2, depth 4
 *
 *   Tandy CoCo3
 *     c2  : linear 1, planar 0, line 256, planes 1, depth 1
 *     c4  : linear 2, planar 0, line 256, planes 1, depth 2
 *     c16 : linear 4, planar 0, line 256, planes 1, depth 4
 *
 * An instance is a conversion recipe and can be reused across images. Nothing
 * is carried from one conversion to the next: a line width of zero means "fit
 * the narrowest line this image needs", and it is computed per image rather
 * than remembered — the command line used to keep the first image's width and
 * apply it to the rest of a directory.
 */
@Slf4j
public class Png2Bin {

	/** post-processing applied to each plane's binary, for the engine modules that want it */
	public enum Buffer {
		NONE,
		/** vertical scroll data buffer */
		VSCROLL,
		/** vertical scroll tile data */
		VSCROLL_TILE,
		/** horizontal scroll code buffer, for a 160px band that loops on itself */
		HSCROLL
	}

	private final int linearBits;
	private final int planarBits;
	private final int lineBytes;      // 0 : fit the narrowest line the image needs
	private final int nbPlanes;
	private final int pixelDepth;
	private final int fileMaxSize;
	private final boolean shiftLeftColors;
	private final Buffer buffer;
	private final int guardColor;

	public Png2Bin(int linearBits, int planarBits, int lineBytes, int nbPlanes, int pixelDepth,
	               int fileMaxSize, boolean shiftLeftColors, Buffer buffer, int guardColor) {
		this.linearBits = linearBits;
		this.planarBits = planarBits;
		this.lineBytes = lineBytes;
		this.nbPlanes = nbPlanes;
		this.pixelDepth = pixelDepth;
		this.fileMaxSize = fileMaxSize <= 0 ? Integer.MAX_VALUE : fileMaxSize;
		this.shiftLeftColors = shiftLeftColors;
		this.buffer = buffer == null ? Buffer.NONE : buffer;
		this.guardColor = guardColor;
	}

	/**
	 * Convert one image next to itself.
	 *
	 * @return the binaries written, plane by plane then part by part
	 */
	public List<String> convert(File pngFile) throws Exception {
		return convert(pngFile, null);
	}

	/**
	 * Convert one image, writing the binaries into outputDir rather than beside
	 * the source. A build that keeps its generated files out of the source tree
	 * wants the second form.
	 *
	 * @return the binaries written, plane by plane then part by part. When a
	 *         Buffer other than NONE is asked for, each of them also has its
	 *         buffer written alongside, under the same name plus a suffix.
	 */
	public List<String> convert(File pngFile, String outputDir) throws Exception {

		if (pngFile == null || !pngFile.exists() || pngFile.isDirectory()) {
			throw new Exception("png2bin : " + pngFile + " is not a readable file");
		}

		Png png = new Png(pngFile);

		// Two ways to reach the pair (width, line), and they are not each other's
		// inverse — asking for a line width pads the image out to it, where
		// letting it be computed only rounds the image up to whole bytes.
		int line = lineBytes;
		int width;
		if (line == 0) {
			int pixelGroup = (nbPlanes * 8) / pixelDepth;
			width = png.width;
			width += (width % pixelGroup != 0 ? pixelGroup - width % pixelGroup : 0);
			line = (width * pixelDepth) / 8;
		} else if ((line * nbPlanes) * (8 / pixelDepth) >= png.width) {
			width = (line * nbPlanes) * (8 / pixelDepth);
		} else {
			throw new Exception("png2bin : " + pngFile.getName() + " is " + png.width
			                  + " pixels wide, which does not fit a line of " + line + " bytes");
		}

		byte[] image = resize(png, width);
		if (shiftLeftColors) stripAlpha(image);
		byte[][] planes = convert(image, png.colorModel.getPixelSize(), png.height, line);

		List<String> files = write(planes, pngFile, outputDir);

		for (String file : files) {
			switch (buffer) {
				case VSCROLL:      new VerticalScroll(file); break;
				case VSCROLL_TILE: new VerticalScrollTile(file); break;
				case HSCROLL:      new HorizontalScroll(file, guardColor); break;
				default: break;
			}
		}
		return files;
	}

	/** indexes shift down by one : index 0 is transparency, 1..16 are colours 0..15 */
	private void stripAlpha(byte[] image) {
		for (int i = 0; i < image.length; i++) {
			if (image[i] != 0) image[i] = (byte) (((image[i] & 0xff) - 1) & 0xff);
		}
	}

	/** pad the image out to the destination width, in pixels */
	private byte[] resize(Png png, int width) {
		int pixelSize = png.colorModel.getPixelSize();
		int dwidth = png.width / (8 / pixelSize);
		int nwidth = width / (8 / pixelSize);
		byte[] image = new byte[nwidth * png.height];
		for (int y = 0; y < png.height; y++) {
			for (int x = 0; x < dwidth; x++) {
				image[x + y * nwidth] = (byte) png.dataBuffer.getElem(x + y * dwidth);
			}
		}
		return image;
	}

	private byte[][] convert(byte[] image, int pixelSize, int height, int line) {

		byte[][] out = new byte[nbPlanes][];
		for (int p = 0; p < nbPlanes; p++) {
			out[p] = new byte[(line * height) / nbPlanes];
		}

		int ibc = 0;                                    // bits read in the input byte
		int curPxRShift = pixelSize;                    // shift inside the pixel
		int curSubPxRShift = pixelDepth - linearBits;   // shift inside the part of a pixel a plane holds
		int[] outIdx = new int[nbPlanes];
		int[] curBitsinByte = new int[nbPlanes];
		int curBitsinPlane = 0;
		int plane = 0;
		int lbmask = 0;

		for (int i = 0; i < linearBits; i++) {
			lbmask = (lbmask << 1) | 1;
		}

		int i = 0;
		while (i < image.length) {

			out[plane][outIdx[plane]] = (byte) ((out[plane][outIdx[plane]] << linearBits)
			                                  | ((image[i] >> 8 - curPxRShift + curSubPxRShift) & lbmask));

			// curSubPxRShift walks through the parts of a pixel a plane holds :
			// with linearBits 2 and pixelDepth 4 it starts at 2 and steps to 0,
			// which is two reads of two bits, then the next pixel.
			curSubPxRShift -= linearBits;
			if (curSubPxRShift < 0) {
				curSubPxRShift = pixelDepth - linearBits;
				curPxRShift += pixelSize;
			}

			curBitsinByte[plane] += linearBits;
			if (curBitsinByte[plane] == 8) {
				outIdx[plane]++;
				curBitsinByte[plane] = 0;
			}

			ibc += linearBits;
			if (ibc == (8 / pixelSize) * pixelDepth) {
				i++;
				ibc = 0;
				curPxRShift = pixelSize;
			}

			curBitsinPlane += linearBits;
			if (curBitsinPlane % planarBits == 0) {
				plane++;
				plane = plane % nbPlanes;
				curBitsinPlane = 0;
			}
		}
		return out;
	}

	/** one file per plane, split again whenever a plane is longer than fileMaxSize */
	private List<String> write(byte[][] out, File pngFile, String outputDir) throws Exception {
		List<String> files = new ArrayList<String>();
		String base = FileUtil.removeExtension(pngFile.toString());
		if (outputDir != null) {
			File dir = new File(outputDir);
			if (!dir.exists() && !dir.mkdirs()) {
				throw new Exception("png2bin : cannot create " + outputDir);
			}
			base = Paths.get(outputDir, FileUtil.removeExtension(pngFile.getName())).toString();
		}
		for (int p = 0; p < nbPlanes; p++) {
			int readIdx = 0;
			int fileId = 0;
			while (readIdx < out[p].length) {
				String filename = base + "." + p + "." + fileId + ".bin";
				files.add(filename);
				byte[] part = new byte[Math.min(out[p].length - readIdx, fileMaxSize)];
				for (int w = 0; w < part.length; w++) {
					part[w] = out[p][readIdx++];
				}
				try (FileOutputStream fos = new FileOutputStream(new File(filename))) {
					fos.write(part);
				}
				fileId++;
			}
		}
		return files;
	}
}
