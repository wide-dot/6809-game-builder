package com.widedot.toolbox.graphics.png2pal;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.awt.Color;
import java.awt.image.ColorModel;
import java.io.IOException;

import javax.imageio.ImageIO;

import com.widedot.m6809.util.FileUtil;
import com.widedot.m6809.util.color.LAB;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Converter {
	
	public static String ASM_EXT = ".asm";
	public static String BIN_EXT = ".bin";
	public static final String OBJ  = "obj";
	public static final String DAT  = "dat";
	public static final String BIN  = "bin";

	private static LAB labColor;
	private static LAB[] paletteLab = new LAB[4096];
	private static int[] paletteRGB = new int[4096];
	private static int rgbProfile[];
	private static HashMap<Integer, Integer> rgbIndex = new HashMap<Integer, Integer>();	

	public static byte[] run(String symbol, String mode, int colors, int offset, String profile, String filename, String dirname, String gensource) {
		
		log.debug("Convert an image file (.png) to palette data in an assembly file (.asm).");
		ByteArrayOutputStream outputStream = new ByteArrayOutputStream( );
		
		try {
			
			// build full palette values
			rgbProfile = FileResourcesUtils.get(profile+".txt");
    		int i = 0;
    		for (int r=0; r<16; r++) {
    			for (int g=0; g<16; g++) {
    				for (int b=0; b<16; b++) {
    					labColor = LAB.fromRGBr(rgbProfile[r], rgbProfile[g], rgbProfile[b], 1.0);
    					paletteLab[i]=labColor;
    					paletteRGB[i] = (0xFF000000 & (255 << 24)) | (0x00FF0000 & (rgbProfile[r] << 16)) | (0x0000FF00 & (rgbProfile[g] << 8)) | (0x000000FF & rgbProfile[b]);
    					i++;
    				}
    			}
    			rgbIndex.put(rgbProfile[r], r);
    		}
			
    		// process indexed colors of png files
			if (filename != null) {
				File file = new File(filename);
				if (symbol == null) {
					symbol = FileUtil.removeExtension(FileUtil.getBasename(filename));
				}
				outputStream.write(convertFile(symbol, mode, colors, offset, file, gensource));
			} else {
				log.debug("Process each .png file of the directory: {}", dirname);
				File dir = new File(dirname);
				if (!dir.exists() || !dir.isDirectory()) {
					log.error("Input directory does not exists !");
				} else {
					File[] files = dir.listFiles((d, name) -> name.endsWith(".png"));
					for (File file : files) {
						if (symbol == null) {
							symbol = FileUtil.removeExtension(FileUtil.getBasename(filename));
						}
						outputStream.write(convertFile(symbol, mode, colors, offset, file, gensource));
					}
				}
			}
			log.debug("Conversion ended sucessfully.");
		} catch (Exception e) {
			e.printStackTrace();
		}
		return outputStream.toByteArray();
	}
	
	private static byte[] convertFile(String symbol, String mode, int colors, int offset, File file, String gensource) throws Exception {
		
		log.debug("Process file: {}", file.getAbsolutePath());
		byte[] result;
		String ext;
		
		// Set nb of colors to process
		ColorModel colorModel = ImageIO.read(file).getColorModel();
		if (colors == 0) colors = (int) Math.pow(2, colorModel.getPixelSize());
		
		// Set the process mode
	     switch (mode) {
         case OBJ:
        	 result = Converter.genObject(symbol, mode, colors, offset, colorModel).getBytes();
        	 ext = ASM_EXT;
             break;
         case DAT:
        	 result = Converter.genData(symbol, mode, colors, offset, colorModel).getBytes();
        	 ext = ASM_EXT;
             break;
         case BIN:
        	 result = Converter.genBinary(symbol, mode, colors, offset, colorModel);
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
	
	public static String genObject(String symbol, String mode, int colors, int offset, ColorModel colorModel) throws IOException {

		// Generate assembly code
		String code = "";
		
		code += symbol + " EXPORT" + System.lineSeparator()
		      + System.lineSeparator()
              + " SECTION code" + System.lineSeparator()
              + symbol + System.lineSeparator();
		
		int nearestColor;
		for (int colorIndex = offset; colorIndex < offset+colors; colorIndex++) {
			Color color = new Color(colorModel.getRGB(colorIndex));
			
			nearestColor = getNearestColor(color);

			int r = rgbIndex.get((nearestColor >> 16) & 0xFF);
			int g = rgbIndex.get((nearestColor >> 8) & 0xFF);
			int b = rgbIndex.get(nearestColor & 0xFF);
			
			log.debug("idx:{}\tRGB:{},{},{}\t({},{},{})", colorIndex-1, color.getRed(), color.getGreen(), color.getBlue(), r, g, b);
			
			code += "        fdb   $"
					+ Integer.toHexString(g)
					+ Integer.toHexString(r)					
					+ "0"
					+ Integer.toHexString(b)
					+ " ; GR0B ("
					+ color.getGreen() + ","
					+ color.getRed()   + ",0,"
					+ color.getBlue()  + ")"
					+ System.lineSeparator();
		}
		
		code += " ENDSECTION" + System.lineSeparator();
		
		return code;
	}
	
	public static String genData(String symbol, String mode, int colors, int offset, ColorModel colorModel) throws IOException {

		// Generate assembly code
		String code = "";
		
		int nearestColor;
		for (int colorIndex = offset; colorIndex < offset+colors; colorIndex++) {
			Color color = new Color(colorModel.getRGB(colorIndex));
			
			nearestColor = getNearestColor(color);

			int r = rgbIndex.get((nearestColor >> 16) & 0xFF);
			int g = rgbIndex.get((nearestColor >> 8) & 0xFF);
			int b = rgbIndex.get(nearestColor & 0xFF);
			
			log.debug("idx:{}\tRGB:{},{},{}\t({},{},{})", colorIndex-1, color.getRed(), color.getGreen(), color.getBlue(), r, g, b);
			
			code += "        fdb   $"
					+ Integer.toHexString(g)
					+ Integer.toHexString(r)					
					+ "0"
					+ Integer.toHexString(b)
					+ " ; GR0B ("
					+ color.getGreen() + ","
					+ color.getRed()   + ",0,"
					+ color.getBlue()  + ")"
					+ System.lineSeparator();
		}
		
		return code;
	}
	
	public static byte[] genBinary(String symbol, String mode, int colors, int offset, ColorModel colorModel) throws IOException {

		// Generate assembly code
		byte[] bin = new byte[colors*2];
		
		int nearestColor;
		for (int colorIndex = offset; colorIndex < offset+colors; colorIndex++) {
			Color color = new Color(colorModel.getRGB(colorIndex));
			
			nearestColor = getNearestColor(color);

			int r = rgbIndex.get((nearestColor >> 16) & 0xFF);
			int g = rgbIndex.get((nearestColor >> 8) & 0xFF);
			int b = rgbIndex.get(nearestColor & 0xFF);
			
			log.debug("idx:{}\tRGB:{},{},{}\t({},{},{})", colorIndex-1, color.getRed(), color.getGreen(), color.getBlue(), r, g, b);
			
			bin[(colorIndex-offset)*2]   = (byte) ((g << 4) + r);
			bin[(colorIndex-offset)*2+1] = (byte) b;
		}
		
		return bin;
	}
	
	private static int getNearestColor(Color color) {
		LAB currentColor = new LAB(0, 0, 0);
		
		int j, nearestColor;
		double distance, minDistance;
		
		currentColor = LAB.fromRGBr(color.getRed(), color.getGreen(), color.getBlue(), 1.0);
		minDistance = Double.POSITIVE_INFINITY;
		nearestColor = 0;
		for (j = 0; j < 4096; j++) {
			distance = LAB.ciede2000(currentColor, paletteLab[j]);
			if (distance < minDistance) {
				nearestColor = paletteRGB[j];
				minDistance = distance;
			}
		}
		return nearestColor;
	}

}