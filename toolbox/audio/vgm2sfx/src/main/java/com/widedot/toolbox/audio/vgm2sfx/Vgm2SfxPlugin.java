package com.widedot.toolbox.audio.vgm2sfx;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;

import com.widedot.m6809.util.FileUtil;
import com.widedot.m6809.util.zx0.Compressor;
import com.widedot.m6809.util.zx0.Optimizer;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Vgm2SfxPlugin {
	
	public static String INPUT_EXT1 = ".vgm";
	public static String INPUT_EXT2 = ".vgz";
	public static String BIN_EXT = ".asm";
	
	public static String filename;
	public static String gensource;

	public static byte[] run() throws Exception {
		
		log.debug("Convert {} or {} to {}", INPUT_EXT1, INPUT_EXT2, BIN_EXT);
		
		// check input file
		File file = new File(filename);
		if (!file.exists()) {
		  String m = "filename: "+filename+" does not exists !";
		  log.error(m);
		  throw new Exception(m);
		}
		
		ByteArrayOutputStream outputStream = new ByteArrayOutputStream( );
		
		if (!file.isDirectory()) {
			
			// Single file processing
			outputStream.write(convertFile(file));
			
		} else {
			
			// Directory processing
			processDirectory(outputStream, file, INPUT_EXT1);
			processDirectory(outputStream, file, INPUT_EXT2);
			
		}
		log.debug("Conversion ended sucessfully.");

		return outputStream.toByteArray();
	}
	
	
	private static void processDirectory(ByteArrayOutputStream outputStream, File file, String fileExt) throws IOException {
		
		log.debug("Process each {} file of the directory: {}", fileExt, file.getAbsolutePath());

		File[] files = file.listFiles((d, name) -> name.endsWith(fileExt));
		for (File curFile : files) {
			outputStream.write(convertFile(curFile));
		}
	}
	
	private static byte[] convertFile(File file) throws IOException {
	
		String outFileName;
		if (gensource == null || gensource.equals(""))
		{
			// output is not specified, produce file in same directory as input file
			outFileName = FileUtil.removeExtension(file.getAbsolutePath()) + BIN_EXT;
		} else {
			if (Files.isDirectory(Paths.get(gensource))) {
				// output directory is specified
				outFileName = gensource + File.separator + FileUtil.removeExtension(file.getName()) + BIN_EXT;
			} else {
				// output file is specified
				outFileName = gensource;
			}
		}
		
		Files.createDirectories(Paths.get(FileUtil.getDir(outFileName)));
		
		// skip processing if input file is older than output file
		long inputLastModified = file.lastModified();
		long outputLastModified = (new File(outFileName)).lastModified();
		
		if (inputLastModified > outputLastModified) {
		
			log.debug("Generating: {}", outFileName);
			VGMInterpreter vGMInterpreter = new VGMInterpreter(file);
	
			byte[] result = vGMInterpreter.getBytes();
			OutputStream outputStream = new FileOutputStream(outFileName);
			outputStream.write(result);
			outputStream.close();
			
			return result;
			
		} else {
			log.debug("Build cache for {}", outFileName);
			return Files.readAllBytes(Paths.get(outFileName));
		}
	}
	
}