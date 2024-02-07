package com.widedot.toolbox.audio.vgm2ymm;

import java.io.ByteArrayOutputStream;
import java.io.File;
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
		byte[] result = null;
		
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
		result = new byte[vGMInterpreter.getLastIndex()];
		for (int b = 0; b < vGMInterpreter.getLastIndex(); b++)
			result[b] = (byte)paramArrayOfint[b];
		
		if (codec.equals(CODEC_ZX0)) {
			log.debug("Compress data with zx0.");
			int originalSize = result.length;
			int[] delta = { 0 };			
			result = new Compressor().compress(new Optimizer().optimize(result, 0, MAX_OFFSET_YMM, 8, false), result, 0, false, false, delta);
			log.debug("Original size: {}, Packed size: {}, Delta: {}", originalSize, result.length, delta[0]);
		}
		
		Files.write(Path.of(outFileName), result);
		return result;
	}
	
}