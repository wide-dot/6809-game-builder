package com.widedot.toolbox.audio.vgm2ymm;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import com.widedot.m6809.util.FileUtil;
import com.widedot.m6809.util.zx0.Compressor;
import com.widedot.m6809.util.zx0.Optimizer;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Converter {
	
	public static String CODEC_NONE = "none";
	public static String CODEC_ZX0 = "zx0";
	public static String INPUT_EXT = ".vgm";
	public static String BIN_EXT = ".ymm";
	public static int MAX_OFFSET_YMM = 512;

	public static byte[] run(String filename, String genbinary, String codec, String drumStr) throws Exception {
		
		log.debug("Convert vgm to ymm");
		
		// check input file
		File file = new File(filename);
		if (!file.exists()) {
		  String m = "filename: "+filename+" does not exists !";
		  log.error(m);
		  throw new Exception(m);
		}
		
		// default values
		if (codec == null) {
			codec = CODEC_NONE;
		}

		ByteArrayOutputStream outputStream = new ByteArrayOutputStream( );
		
		int[] drum = null;
		if (drumStr != null) {
			String[] drumValues = drumStr.split(",");
			drum = new int[3];
			drum[0] = Integer.decode(drumValues[0]);
			drum[1] = Integer.decode(drumValues[1]);
			drum[2] = Integer.decode(drumValues[2]);
		}
		
		if (!file.isDirectory()) {
			
			// Single file processing
			outputStream.write(convertFile(file, genbinary, codec, drum));
			
		} else {
			
			// Directory processing
			log.debug("Process each .png file of the directory: {}", filename);

			File[] files = file.listFiles((d, name) -> name.endsWith(INPUT_EXT));
			for (File curFile : files) {
				outputStream.write(convertFile(curFile, genbinary, codec, drum));
			}
			
		}
		log.debug("Conversion ended sucessfully.");

		return outputStream.toByteArray();
	}
	
	private static byte[] convertFile(File file, String genFileName, String codec, int[] drum) throws IOException {
	
		String outFileName;
		if (genFileName == null || genFileName.equals(""))
		{
			// output is not specified, produce file in same directory as input file
			outFileName = FileUtil.removeExtension(file.getAbsolutePath()) + BIN_EXT;
		} else {
			if (Files.isDirectory(Paths.get(genFileName))) {
				// output directory is specified
				outFileName = genFileName + File.separator + FileUtil.removeExtension(file.getName()) + BIN_EXT;
			} else {
				// output file is specified
				outFileName = genFileName;
			}
		}
		
		Files.createDirectories(Paths.get(FileUtil.getDir(outFileName)));
		VGMInterpreter vGMInterpreter = new VGMInterpreter(file, drum);

		int[] paramArrayOfint = vGMInterpreter.getArrayOfInt();
		
		byte[] intro = null;
		if (vGMInterpreter.loopMarkerHit > 0) {
			intro = new byte[vGMInterpreter.loopMarkerHit+1]; // make room for end marker
			int b;
			for (b = 0; b < vGMInterpreter.loopMarkerHit; b++)
				intro[b] = (byte)paramArrayOfint[b];
			intro[b] = 0x39;
		}
		
		byte[] loop = null;
		if (vGMInterpreter.getLastIndex()-vGMInterpreter.loopMarkerHit > 0) {
			loop = new byte[vGMInterpreter.getLastIndex()-vGMInterpreter.loopMarkerHit];
			int i = 0;
			for (int b = vGMInterpreter.loopMarkerHit; b < vGMInterpreter.getLastIndex(); b++)
				loop[i++] = (byte)paramArrayOfint[b];
		}
		
		if (codec.equals(CODEC_ZX0)) {
			if (intro != null) {
				log.debug("Compress intro data with zx0.");
				int originalSize = intro.length;
				int[] delta = { 0 };			
				intro = new Compressor().compress(new Optimizer().optimize(intro, 0, MAX_OFFSET_YMM, 8, false), intro, 0, false, false, delta);
				log.debug("Original size: {}, Packed size: {}, Delta: {}", originalSize, intro.length, delta[0]);
			}
			
			if (loop != null) {
				log.debug("Compress loop data with zx0.");
				int originalSize = loop.length;
				int[] delta = { 0 };			
				loop = new Compressor().compress(new Optimizer().optimize(loop, 0, MAX_OFFSET_YMM, 8, false), loop, 0, false, false, delta);
				log.debug("Original size: {}, Packed size: {}, Delta: {}", originalSize, loop.length, delta[0]);
			}
		}

		ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
		if (intro != null) {
			outputStream.write(((intro.length+2) >> 8) & 0xff); // +2 will place the cursor to entry point
			outputStream.write((intro.length+2) & 0xff);
			outputStream.write(intro);
		} else {
			outputStream.write(0);
			outputStream.write(2);
		}
		
		if (loop != null) {
			outputStream.write(loop);
		}
		
		OutputStream fileStream = new FileOutputStream(outFileName);
		outputStream.writeTo(fileStream);
		
		return outputStream.toByteArray();
	}
	
}