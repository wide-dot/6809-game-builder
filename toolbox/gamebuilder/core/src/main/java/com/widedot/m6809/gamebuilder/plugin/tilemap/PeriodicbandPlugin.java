package com.widedot.m6809.gamebuilder.plugin.tilemap;

import java.awt.image.BufferedImage;
import java.awt.image.IndexColorModel;
import java.awt.image.WritableRaster;
import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import javax.imageio.ImageIO;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;

import lombok.extern.slf4j.Slf4j;

/**
 * Handler for the &lt;periodicband&gt; element : a picture whose pattern
 * repeats along x, made ready for engine/graphics/tilemap/periodicband (the
 * runtime that draws it at any horizontal phase, BM16).
 *
 * The picture is indexed, index 0 transparent, and its lines fall in three
 * kinds :
 * <ul>
 * <li>FULL lines (no transparent pixel) : drawn by the runtime's writer from
 *     tables, one per line, emitted in the generated source ;</li>
 * <li>empty lines : nothing ;</li>
 * <li>the others, the STEMS : from the first to the last of them, a sheet of
 *     16 pixel wide strips is written for a &lt;gfxcomp grid&gt;, both pixel
 *     parities side by side (parity 0 then parity 1, period/16 strips each) ;
 *     a full line inside that range is transparent there, the writer has it.</li>
 * </ul>
 *
 * A line's tables, for the parity e (the pixel shift) : the period's pixel
 * pairs (2k+e, 2k+1+e) as BM16 bytes (index - 1 per nibble, gfxcomp's
 * convention), the even pairs then the odd ones — what the plane of the first
 * pixel pair and the other plane show — each doubled so any rotation reads in
 * one go. 2 x period bytes a line.
 *
 * The generated source holds the geometry (periodicband.* equates), the runs
 * of consecutive full lines (screen offset, count, tables), the tables, and
 * the strip table the runtime walks : per parity, the strips adr_&lt;tiles&gt;_&lt;id&gt;_ND0
 * repeated to 12 entries, so 10 consecutive strips read in one go.
 */
@Slf4j
public class PeriodicbandPlugin {

	public static final int STRIP = 16;        // strip width, pixels : 160 px = 10 strips
	public static final int STRIP_ENTRIES = 12; // strip table entries per parity
	public static final int LINE_BYTES = 40;    // BM16 bytes per line and plane

	public static File getFile(ImmutableNode node, BuildContext ctx) throws Exception {

		String image = ctx.path + File.separator + Attribute.getString(node, ctx, "image");
		int period = Attribute.getInteger(node, ctx, "period");
		String tiles = Attribute.getString(node, ctx, "tiles");
		String sheet = ctx.path + File.separator + Attribute.getString(node, ctx, "sheet");
		String gensource = ctx.path + File.separator + Attribute.getString(node, ctx, "gensource");
		int x = Attribute.getInteger(node, ctx, "x", 8);
		int y = Attribute.getInteger(node, ctx, "y", 0);
		int width = Attribute.getInteger(node, ctx, "width", 144);
		String section = Attribute.getString(node, ctx, "section", "code");

		BufferedImage picture = ImageIO.read(new File(image));
		if (picture == null || !(picture.getColorModel() instanceof IndexColorModel)) {
			throw new Exception("periodicband " + image + " : an indexed PNG is expected");
		}
		Band band = new Band(picture.getRaster(), period, x, y, width, image);
		band.check();

		writeSheet(band, picture, sheet);
		String source = band.source(image, tiles, section);
		Path path = Paths.get(gensource);
		if (path.getParent() != null) {
			Files.createDirectories(path.getParent());
		}
		Files.writeString(path, source);
		log.info("periodicband {} : period {}, {} full lines in {} runs, strips over lines {}-{}, {} bytes of tables",
				image, period, band.fullCount(), band.runs().size(),
				band.stemsTop, band.stemsBottom, band.fullCount() * 2 * period);
		return path.toFile();
	}

	/** The picture's analysis and the generated source, apart from the files (tested alone). */
	static class Band {
		final java.awt.image.Raster raster;
		final int period, x, y, width, w, h;
		final String name;
		final boolean[] full;
		int stemsTop = -1, stemsBottom = -1;

		Band(java.awt.image.Raster raster, int period, int x, int y, int width, String name) {
			this.raster = raster;
			this.period = period;
			this.x = x;
			this.y = y;
			this.width = width;
			this.name = name;
			this.w = raster.getWidth();
			this.h = raster.getHeight();
			full = new boolean[h];
			for (int line = 0; line < h; line++) {
				boolean any = false, all = true;
				for (int i = 0; i < w; i++) {
					boolean opaque = raster.getSample(i, line, 0) != 0;
					any |= opaque;
					all &= opaque;
				}
				full[line] = all;
				if (any && !all) {
					if (stemsTop < 0) {
						stemsTop = line;
					}
					stemsBottom = line;
				}
			}
		}

		void check() throws Exception {
			String what = "periodicband " + name + " : ";
			if (period <= 0 || period % STRIP != 0) {
				throw new Exception(what + "period " + period + " is not a multiple of " + STRIP + " pixels");
			}
			if (w % period != 0) {
				throw new Exception(what + "width " + w + " is not a whole number of periods of " + period);
			}
			for (int line = 0; line < h; line++) {
				for (int i = period; i < w; i++) {
					if (raster.getSample(i, line, 0) != raster.getSample(i - period, line, 0)) {
						throw new Exception(what + "pixel (" + i + "," + line + ") breaks the period of "
								+ period + " : it is not the pixel " + period + " to its left");
					}
				}
			}
			if (width <= 0 || width % period != 0) {
				throw new Exception(what + "visible width " + width + " is not a whole number of periods of " + period);
			}
			if (x < 0 || x % 4 != 0 || x + width > 4 * LINE_BYTES) {
				throw new Exception(what + "x " + x + " must be a multiple of 4 and the window inside the 160 px line");
			}
			if (y < 0 || y + h > 200) {
				throw new Exception(what + "lines " + y + "-" + (y + h - 1) + " outside the 200 lines of the screen");
			}
			for (int line = 0; line < h; line++) {
				for (int i = 0; i < w; i++) {
					if (raster.getSample(i, line, 0) > 16) {
						throw new Exception(what + "pixel (" + i + "," + line + ") is index "
								+ raster.getSample(i, line, 0) + ", above the 16 colours of BM16 (+1)");
					}
				}
			}
		}

		int pixel(int i, int line) {
			return raster.getSample(Math.floorMod(i, period), line, 0);
		}

		/** the BM16 byte of the pixel pair starting at i */
		int pair(int i, int line) {
			return ((pixel(i, line) - 1) << 4) | (pixel(i + 1, line) - 1);
		}

		int fullCount() {
			int n = 0;
			for (boolean f : full) {
				n += f ? 1 : 0;
			}
			return n;
		}

		/** runs of consecutive full lines : {first line, count} */
		java.util.List<int[]> runs() {
			java.util.List<int[]> runs = new java.util.ArrayList<>();
			for (int line = 0; line < h; line++) {
				if (full[line] && (line == 0 || !full[line - 1])) {
					int n = 0;
					while (line + n < h && full[line + n]) {
						n++;
					}
					runs.add(new int[] { line, n });
				}
			}
			return runs;
		}

		/** one full line's tables : per parity, the even pairs then the odd ones, each doubled */
		int[] tables(int line) {
			int bytes = period / 4;                // a plane's bytes in a period
			int[] t = new int[2 * period];
			int k = 0;
			for (int e = 0; e < 2; e++) {
				for (int odd = 0; odd < 2; odd++) {
					for (int copy = 0; copy < 2; copy++) {
						for (int m = 0; m < bytes; m++) {
							t[k++] = pair(4 * m + 2 * odd + e, line);
						}
					}
				}
			}
			return t;
		}

		/** the strip sheet's pixel : column c of the sheet, line l of the strips */
		int sheetPixel(int c, int l) {
			int line = stemsTop + l;
			if (full[line]) {
				return 0;                          // the writer's line
			}
			int perParity = period;               // the parity's strips side by side
			int e = c / perParity;
			return pixel(c % perParity + e, line);
		}

		String source(String image, String tiles, String section) {
			String nl = System.lineSeparator();
			StringBuilder s = new StringBuilder();
			s.append("* Generated by periodicband from ").append(image).append(nl);
			s.append("* period ").append(period).append(" px, window x ").append(x).append(" width ")
					.append(width).append(", picture lines at screen lines ").append(y).append('-')
					.append(y + h - 1).append(nl);
			s.append("periodicband.PERIOD      equ ").append(period).append(nl);
			s.append("periodicband.WIDTH       equ ").append(width).append(nl);
			s.append("periodicband.X           equ ").append(x).append(nl);
			java.util.List<int[]> runs = runs();
			s.append("periodicband.RUNS        equ ").append(runs.size()).append(nl);
			boolean stems = stemsTop >= 0;
			s.append("periodicband.STEMS       equ ").append(stems ? 1 : 0).append(nl);
			s.append("periodicband.STEMS.Y     equ ").append(stems ? y + stemsTop : 0).append(nl);
			s.append("periodicband.STEMS.H     equ ").append(stems ? stemsBottom - stemsTop + 1 : 0).append(nl);
			s.append("periodicband.STRIP.ENTRIES equ ").append(STRIP_ENTRIES).append(nl);
			s.append(nl);
			s.append(" SECTION ").append(section).append(nl);
			s.append("* the runs of full lines : video offset of the first line, line count,").append(nl);
			s.append("* the first line's tables").append(nl);
			s.append("periodicband.runs").append(nl);
			int table = 0;
			for (int[] run : runs) {
				s.append("        fdb   ").append((y + run[0]) * LINE_BYTES).append("              ; line ")
						.append(y + run[0]).append(nl);
				s.append("        fcb   ").append(run[1]).append(nl);
				s.append("        fdb   periodicband.lines+").append(table * 2 * period).append(nl);
				table += run[1];
			}
			s.append(nl);
			s.append("* per full line, ").append(2 * period)
					.append(" bytes : parity 0 then 1, each the even pixel pairs then the odd ones, doubled")
					.append(nl);
			s.append("periodicband.lines").append(nl);
			for (int[] run : runs) {
				for (int line = run[0]; line < run[0] + run[1]; line++) {
					s.append("* line ").append(y + line).append(nl);
					int[] t = tables(line);
					int chunk = period / 4;
					for (int i = 0; i < t.length; i += chunk) {
						s.append("        fcb   ");
						for (int j = 0; j < chunk; j++) {
							s.append(j == 0 ? "" : ",").append(String.format("$%02X", t[i + j]));
						}
						s.append(nl);
					}
				}
			}
			if (stems) {
				s.append(nl);
				s.append("* the strips, per parity ").append(period / STRIP).append(" routines repeated to ")
						.append(STRIP_ENTRIES).append(" entries").append(nl);
				s.append("periodicband.strips").append(nl);
				for (int e = 0; e < 2; e++) {
					for (int i = 0; i < STRIP_ENTRIES; i++) {
						int id = e * (period / STRIP) + i % (period / STRIP);
						s.append("        fdb   adr_").append(tiles).append('_').append(id).append("_ND0")
								.append(nl);
					}
				}
			}
			s.append(" ENDSECTION").append(nl);
			return s.toString();
		}
	}

	static void writeSheet(Band band, BufferedImage picture, String sheet) throws Exception {
		if (band.stemsTop < 0) {
			return;
		}
		int w = 2 * band.period;
		int h = band.stemsBottom - band.stemsTop + 1;
		// the picture's palette in an 8 bit model, whatever its PNG bit depth
		IndexColorModel src = (IndexColorModel) picture.getColorModel();
		int size = src.getMapSize();
		byte[] red = new byte[size], green = new byte[size], blue = new byte[size];
		src.getReds(red);
		src.getGreens(green);
		src.getBlues(blue);
		BufferedImage out = new BufferedImage(w, h, BufferedImage.TYPE_BYTE_INDEXED,
				new IndexColorModel(8, size, red, green, blue));
		WritableRaster r = out.getRaster();
		for (int l = 0; l < h; l++) {
			for (int c = 0; c < w; c++) {
				r.setSample(c, l, 0, band.sheetPixel(c, l));
			}
		}
		Path path = Paths.get(sheet);
		if (path.getParent() != null) {
			Files.createDirectories(path.getParent());
		}
		ImageIO.write(out, "png", path.toFile());
	}
}
