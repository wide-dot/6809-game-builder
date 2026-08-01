package com.widedot.toolbox.graphics.png;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.Binary;
import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;

import lombok.extern.slf4j.Slf4j;

/**
 * Handler for the &lt;png2bin&gt; element : an indexed PNG becomes video memory
 * data, one direntry per plane.
 *
 * A conversion is a handful of numbers describing how a pixel is laid out in
 * memory. Rather than spell them out, name the video mode :
 *
 *   &lt;png2bin filename="src/band.png" gendir="gen/band"
 *            videomode="bm16" buffer="hscroll" guardcolor="11" plane="0"/&gt;
 *
 * The element yields **one plane**, because a direntry is one file and the two
 * planes of a Thomson bitmap live at two different addresses. Declare it twice,
 * once per plane ; the conversion itself runs once per declaration and writes
 * the same bytes, so the two agree by construction.
 */
@Slf4j
public class Png2BinPlugin {

	/** the pixel layouts, as named in the hardware documentation */
	private static final Map<String, int[]> MODES = new LinkedHashMap<>();
	static {
		//                        linearBits, planarBits, lineBytes, planes, pixelDepth
		MODES.put("t0",  new int[]{1, 0,  40, 1, 1});   // 320x200x1
		MODES.put("t1",  new int[]{1, 1,  40, 2, 2});   // 320x200x4
		MODES.put("t1s", new int[]{2, 8,  40, 2, 2});   // 320x200x4, shifted
		MODES.put("t2",  new int[]{1, 8,  40, 2, 1});   // 640x200x1
		MODES.put("bm16",new int[]{4, 8,   0, 2, 4});   // 160x200x16, the TO8 bitmap mode
		MODES.put("c2",  new int[]{1, 0, 256, 1, 1});   // CoCo3
		MODES.put("c4",  new int[]{2, 0, 256, 1, 2});
		MODES.put("c16", new int[]{4, 0, 256, 1, 4});
	}

	private static final Map<String, Png2Bin.Buffer> BUFFERS = new LinkedHashMap<>();
	static {
		BUFFERS.put("none",         Png2Bin.Buffer.NONE);
		BUFFERS.put("vscroll",      Png2Bin.Buffer.VSCROLL);
		BUFFERS.put("vscrolltile",  Png2Bin.Buffer.VSCROLL_TILE);
		BUFFERS.put("hscroll",      Png2Bin.Buffer.HSCROLL);
	}

	public static ObjectDataInterface getObject(ImmutableNode node, BuildContext ctx) throws Exception {

		String filename   = Attribute.getString(node, ctx, "filename");
		String gendir     = Attribute.getStringOpt(node, ctx, "gendir");
		String videomode  = Attribute.getStringOpt(node, ctx, "videomode");
		String bufferName = Attribute.getString(node, ctx, "buffer", "none");
		Integer plane     = Attribute.getInteger(node, ctx, "plane", 0);
		Integer part      = Attribute.getInteger(node, ctx, "part", 0);
		Integer guard     = Attribute.getInteger(node, ctx, "guardcolor", 0);
		Integer maxsize   = Attribute.getInteger(node, ctx, "maxsize", 0);
		Boolean shift     = Attribute.getBoolean(node, ctx, "shiftcolors", true);

		Png2Bin.Buffer buffer = BUFFERS.get(bufferName.toLowerCase());
		if (buffer == null) {
			throw new Exception("png2bin : buffer '" + bufferName + "' is not one of " + BUFFERS.keySet());
		}

		int linearBits, planarBits, lineBytes, planes, pixelDepth;
		if (videomode != null) {
			int[] m = MODES.get(videomode.toLowerCase());
			if (m == null) {
				throw new Exception("png2bin : videomode '" + videomode + "' is not one of " + MODES.keySet());
			}
			linearBits = m[0]; planarBits = m[1]; lineBytes = m[2]; planes = m[3]; pixelDepth = m[4];
		} else {
			// spelled out, for a layout the named modes do not cover
			linearBits = Attribute.getInteger(node, ctx, "linearbits", 0);
			planarBits = Attribute.getInteger(node, ctx, "planarbits", 0);
			lineBytes  = Attribute.getInteger(node, ctx, "linebytes", 0);
			planes     = Attribute.getInteger(node, ctx, "planes", 1);
			pixelDepth = Attribute.getInteger(node, ctx, "pixeldepth", 0);
			if (linearBits == 0 || pixelDepth == 0) {
				throw new Exception("png2bin : give a videomode, or linearbits and pixeldepth");
			}
		}
		if (plane < 0 || plane >= planes) {
			throw new Exception("png2bin : plane " + plane + " does not exist, this mode has " + planes);
		}

		File png = new File(ctx.path + File.separator + filename);
		String outDir = gendir == null ? null : ctx.path + File.separator + gendir;

		Png2Bin png2bin = new Png2Bin(linearBits, planarBits, lineBytes, planes, pixelDepth,
		                              maxsize, shift, buffer, guard);
		List<String> files = png2bin.convert(png, outDir);

		// files come back plane by plane then part by part ; pick the one asked for
		String wanted = null;
		String suffix = "." + plane + "." + part + ".bin";
		for (String f : files) {
			if (f.endsWith(suffix)) { wanted = f; break; }
		}
		if (wanted == null) {
			throw new Exception("png2bin : " + png.getName() + " has no plane " + plane
			                  + " part " + part + " — it produced " + files);
		}
		if (buffer != Png2Bin.Buffer.NONE) {
			wanted = wanted + "." + bufferName.toLowerCase();
		}

		byte[] data = Files.readAllBytes(Paths.get(wanted));
		log.info("png2bin {} plane {} : {} bytes", png.getName(), plane, data.length);
		return new Binary(data);
	}
}
