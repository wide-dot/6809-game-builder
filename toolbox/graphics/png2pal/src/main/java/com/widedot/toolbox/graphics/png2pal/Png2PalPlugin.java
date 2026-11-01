package com.widedot.toolbox.graphics.png2pal;

import org.apache.commons.configuration2.tree.ImmutableNode;
import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.Binary;
import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.awt.Color;
import java.awt.image.ColorModel;
import java.io.IOException;

import javax.imageio.ImageIO;

import com.widedot.m6809.util.FileUtil;
import com.widedot.m6809.util.color.LAB;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Png2PalPlugin {
	
	public static String ASM_EXT = ".asm";
	public static String BIN_EXT = ".bin";
	public static final String OBJ  = "obj";
	public static final String DAT  = "dat";
	public static final String BIN  = "bin";

	/** what is read and how it is converted, beyond the colours and the offset */
	public static final class Options {
		/** png : the PNG's PLTE ; rgb12 : a binary of big endian $0RGB words (Amiga, Atari ST) */
		public String format = "png";
		/** rgb12 : palettes of {@code colors} words, one after the other from the file's start */
		public int palettes = 1;
		/** black, from, floor in L* : the darks spread above the TO8's first level (Conversion) */
		public double[] lift;
		/** the darkest colour of each palette written black */
		public boolean darkestBlack;
	}

	public static byte[] run(String symbol, String mode, int colors, int offset, String profile, String filename, String gensource) throws Exception {
		return run(symbol, mode, colors, offset, profile, filename, gensource, "code");
	}

	public static byte[] run(String symbol, String mode, int colors, int offset, String profile, String filename, String gensource, String section) throws Exception {
		return run(symbol, mode, colors, offset, profile, filename, gensource, section, new Options());
	}

	/**
	 * @param section name of the generated SECTION. A host unit whose whole body
	 *        is baked names its own section {@code code.static} ; the palette then
	 *        has to stop being called {@code code}, or it would merge with nothing
	 *        and lead the binary in the entry point's place.
	 */
	// the toolchain signals build errors with plain Exceptions
	@SuppressWarnings("PMD.AvoidThrowingRawExceptionTypes")
	public static byte[] run(String symbol, String mode, int colors, int offset, String profile, String filename, String gensource, String section, Options options) throws Exception {
		
		log.debug("Process one or more PNG files to extract and convert indexed palette data.");
		ByteArrayOutputStream outputStream = new ByteArrayOutputStream( );
		Conversion conversion = new Conversion(FileResourcesUtils.get(profile+".txt"), options.lift, options.darkestBlack);
		
		// process indexed colors of png files
		File file = new File(filename);
		if (!file.exists()) {
		  String m = "filename: "+filename+" does not exists !";
		  log.error(m);
		  throw new Exception(m);
		}
		
		if ("rgb12".equals(options.format)) {
			if (file.isDirectory()) {
				throw new Exception("png2pal : format rgb12 reads one file, " + filename + " is a directory");
			}
			outputStream.write(convertFile(symbol, mode, colors, rgb12(file, colors, options.palettes), file, gensource, section, conversion));
		} else if (!"png".equals(options.format)) {
			throw new Exception("png2pal : format '" + options.format + "' is not one of [png, rgb12]");
		} else if (!file.isDirectory()) {
			
			// Single file processing
			outputStream.write(convertFile(symbol, mode, colors, png(file, colors, offset), file, gensource, section, conversion));
		} else {
			
			// Directory processing
			log.debug("Process each .png file of the directory: {}", filename);

			File[] files = file.listFiles((d, name) -> name.endsWith(".png"));
			for (File curFile : files) {
				outputStream.write(convertFile(symbol, mode, colors, png(curFile, colors, offset), curFile, gensource, section, conversion));
			}
		}
		log.debug("Conversion ended sucessfully.");

		return outputStream.toByteArray();
	}

	/** a PNG's colours offset..offset+colors (colors 0 : as many as its pixel size allows) */
	private static List<Color> png(File file, int colors, int offset) throws IOException {
		ColorModel colorModel = ImageIO.read(file).getColorModel();
		int n = colors == 0 ? (int) Math.pow(2, colorModel.getPixelSize()) : colors;
		List<Color> out = new ArrayList<>();
		for (int i = offset; i < offset + n; i++) {
			out.add(new Color(colorModel.getRGB(i)));
		}
		return out;
	}

	/** palettes of big endian $0RGB words : a component c is c * 17 */
	// the toolchain signals build errors with plain Exceptions
	@SuppressWarnings("PMD.AvoidThrowingRawExceptionTypes")
	static List<Color> rgb12(File file, int colors, int palettes) throws Exception {
		byte[] data = Files.readAllBytes(file.toPath());
		if (data.length < 2 * colors * palettes) {
			throw new Exception("png2pal : " + file.getName() + " holds " + data.length / 2 + " words, not "
			                  + palettes + " palettes of " + colors);
		}
		List<Color> out = new ArrayList<>();
		for (int i = 0; i < colors * palettes; i++) {
			int w = (data[2 * i] & 0xFF) << 8 | data[2 * i + 1] & 0xFF;
			out.add(new Color(((w >> 8) & 15) * 17, ((w >> 4) & 15) * 17, (w & 15) * 17));
		}
		return out;
	}
	
	private static byte[] convertFile(String symbol, String mode, int colors, List<Color> colours, File file, String gensource, String section, Conversion conversion) throws Exception {
		
		log.debug("Process file: {}", file.getAbsolutePath());
		byte[] result;
		String ext;
		int[][] levels = conversion.levels(colours, colors == 0 ? colours.size() : colors);
		
		// Set the process mode
	     switch (mode) {
         case OBJ:
     		 if (symbol == null) symbol = FileUtil.removeExtension(file.getName());
        	 result = Png2PalPlugin.genObject(symbol, colours, levels, section).getBytes();
        	 ext = ASM_EXT;
             break;
         case DAT:
        	 result = Png2PalPlugin.genData(symbol, colours, levels).getBytes();
        	 ext = ASM_EXT;
             break;
         case BIN:
        	 result = Png2PalPlugin.genBinary(levels);
        	 ext = BIN_EXT;
             break;
         default:
             throw new IllegalArgumentException("Invalid mode: " + mode);
	     }
		
		String outFileName;
		if (gensource == null || gensource.equals(""))
		{
			// output is not specified, produce file in same directory as input file
			outFileName = FileUtil.removeExtension(file.getAbsolutePath()) + ext;
		} else {
			if (Files.isDirectory(Paths.get(gensource))) {
				// output directory is specified
				outFileName = gensource + File.separator + FileUtil.removeExtension(file.getName()) + ext;
			} else {
				// output file is specified
				outFileName = gensource;
			}
		}
		
		Files.createDirectories(Paths.get(FileUtil.getDir(outFileName)));
		Files.write(Path.of(outFileName), result);
		return result;
	}
	
	public static String genObject(String symbol, List<Color> colours, int[][] levels, String section) {

		// Generate assembly code
		StringBuilder code = new StringBuilder();
		code.append(symbol).append(" EXPORT").append(System.lineSeparator())
		    .append(System.lineSeparator())
		    .append(" SECTION ").append(section).append(System.lineSeparator())
		    .append(symbol).append(System.lineSeparator());
		code.append(entries(colours, levels));
		code.append(" ENDSECTION").append(System.lineSeparator());
		return code.toString();
	}
	
	public static String genData(String symbol, List<Color> colours, int[][] levels) {
		return symbol + System.lineSeparator() + entries(colours, levels);
	}

	private static String entries(List<Color> colours, int[][] levels) {
		StringBuilder code = new StringBuilder();
		for (int i = 0; i < levels.length; i++) {
			Color color = colours.get(i);
			int r = levels[i][0];
			int g = levels[i][1];
			int b = levels[i][2];
			log.debug("idx:{}\tRGB:{},{},{}\t({},{},{})", i, color.getRed(), color.getGreen(), color.getBlue(), r, g, b);
			code.append("        fdb   $")
			    .append(Integer.toHexString(g))
			    .append(Integer.toHexString(r))
			    .append("0")
			    .append(Integer.toHexString(b))
			    .append(" ; GR0B (")
			    .append(color.getGreen()).append(",")
			    .append(color.getRed()).append(",0,")
			    .append(color.getBlue()).append(")")
			    .append(System.lineSeparator());
		}
		return code.toString();
	}
	
	public static byte[] genBinary(int[][] levels) {
		byte[] bin = new byte[levels.length * 2];
		for (int i = 0; i < levels.length; i++) {
			bin[i * 2]     = (byte) ((levels[i][1] << 4) + levels[i][0]);
			bin[i * 2 + 1] = (byte) levels[i][2];
		}
		return bin;
	}

	/** format, palettes, lift, darkest : the element's attributes beyond the colours */
	// the toolchain signals build errors with plain Exceptions
	@SuppressWarnings("PMD.AvoidThrowingRawExceptionTypes")
	static Options options(ImmutableNode node, BuildContext ctx) throws Exception {
		Options o = new Options();
		o.format = Attribute.getString(node, ctx, "format", "png").toLowerCase();
		if (!o.format.equals("png") && !o.format.equals("rgb12")) {
			throw new Exception("png2pal : format '" + o.format + "' is not one of [png, rgb12]");
		}
		o.palettes = Attribute.getInteger(node, ctx, "palettes", 1);
		if (o.palettes < 1 || (o.palettes > 1 && !o.format.equals("rgb12"))) {
			throw new Exception("png2pal : palettes " + o.palettes + " : several palettes come from format rgb12");
		}
		String lift = Attribute.getStringOpt(node, ctx, "lift");
		if (lift != null) {
			String[] v = lift.split(",");
			if (v.length != 3) {
				throw new Exception("png2pal : lift '" + lift + "' is not black,from,floor");
			}
			o.lift = new double[] {Double.parseDouble(v[0].trim()), Double.parseDouble(v[1].trim()), Double.parseDouble(v[2].trim())};
			if (!(o.lift[0] <= o.lift[1] && o.lift[1] < 100 && o.lift[2] < 100)) {
				throw new Exception("png2pal : lift '" + lift + "' : black <= from < 100 and floor < 100");
			}
		}
		String darkest = Attribute.getString(node, ctx, "darkest", "keep").toLowerCase();
		if (!darkest.equals("keep") && !darkest.equals("black")) {
			throw new Exception("png2pal : darkest '" + darkest + "' is not one of [keep, black]");
		}
		o.darkestBlack = darkest.equals("black");
		return o;
	}

	/**
	 * Handler for the <png2pal> element, registered by the builder.
	 */
	/**
	 * Handler for &lt;png2pal&gt; used as the content of a direntry : the palette
	 * becomes a loadable file of 32 bytes, and the game points Pal_current at
	 * the region address it was loaded into.
	 *
	 * Only the binary form makes sense here. The source forms used to be
	 * reachable through this path and would have written assembly text onto the
	 * media ; inside a &lt;lwasm&gt; unit, use the element as a source instead.
	 */
	public static ObjectDataInterface getObject(ImmutableNode node, BuildContext ctx) throws Exception {
	  
	  //read input xml
	  String symbol = Attribute.getStringOpt(node, ctx, "symbol");
	  String mode = Attribute.getString(node, ctx, "mode", Png2PalPlugin.BIN);
	  if (!Png2PalPlugin.BIN.equals(mode)) {
		  throw new Exception("png2pal mode '" + mode + "' : a direntry holds data, not source. "
		                    + "Put the element inside a <lwasm> unit to get a linkable table, "
		                    + "or use mode bin here.");
	  }
	  Integer colors = Attribute.getInteger(node, ctx, "colors", 16);
	  Integer offset = Attribute.getInteger(node, ctx, "offset", 1);
	  String profile = Attribute.getString(node, ctx, "profile", "to");
	  String filename = Attribute.getStringOpt(node, ctx, "filename");
	  String gensource = Attribute.getStringOpt(node, ctx, "gensource");

	  if ((filename == null || filename.equals(""))) {
		  String m = "An input filename should be provided for png2pal!";
		  log.error(m);
		  throw new Exception(m);
	  }
	  
	  if (filename != null) filename = ctx.path + File.separator + filename;
	  if (gensource != null) gensource = ctx.path + File.separator + gensource;
			byte[] data = Png2PalPlugin.run(symbol, mode, colors, offset, profile, filename, gensource, "code", options(node, ctx));
	  return new Binary(data);
	}

	/**
	 * Handler for &lt;png2pal&gt; inside a &lt;lwasm&gt; unit : the palette is
	 * assembled with the code that uses it and its label is exported, so the
	 * load time linker resolves it like any other symbol.
	 *
	 * The runtime reads the table through the Pal_current pointer, and
	 * PalUpdateNow runs under interrupt — so a palette reached that way has to
	 * sit in memory that is always addressable. Generating it into the game
	 * mode's own unit is the simple answer ; a palette living in a paged region
	 * has to be copied into Pal_buffer while its page is mounted.
	 */
	public static File getFile(ImmutableNode node, BuildContext ctx) throws Exception {

	  String symbol = Attribute.getStringOpt(node, ctx, "symbol");
	  Integer colors = Attribute.getInteger(node, ctx, "colors", 16);
	  Integer offset = Attribute.getInteger(node, ctx, "offset", 1);
	  String profile = Attribute.getString(node, ctx, "profile", "to");
	  String filename = Attribute.getStringOpt(node, ctx, "filename");
	  String gensource = Attribute.getStringOpt(node, ctx, "gensource");
	  String section = Attribute.getString(node, ctx, "section", "code");

	  if (filename == null || filename.equals("")) {
		  throw new Exception("An input filename should be provided for png2pal!");
	  }
	  filename = ctx.path + File.separator + filename;

	  if (gensource == null || gensource.equals("")) {
		  gensource = ctx.settings.get("generate.unnamedFiles.dir") + File.separator
		            + (symbol != null ? symbol : FileUtil.removeExtension(new File(filename).getName()))
		            + ".palette.asm";
	  }
	  gensource = ctx.path + File.separator + gensource;

	  // the exported form : one label the rest of the game can link against
	  Png2PalPlugin.run(symbol, Png2PalPlugin.OBJ, colors, offset, profile, filename, gensource, section, options(node, ctx));
	  return new File(gensource);
	}
}