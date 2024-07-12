package com.widedot.toolbox.audio.pcm;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Paths;

import com.widedot.m6809.util.FileUtil;
import com.widedot.m6809.util.zx0.Compressor;
import com.widedot.m6809.util.zx0.Optimizer;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class PcmPlugin {
	
	public static String filename;
	public static String genbinary;
	public static boolean downscale8To6Bit;
	
	private static byte[] convertFile(File srcFile) throws Exception {

		String fileSuffix = "";
		ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
		
		Pcm pcm = new Pcm(srcFile);
		
		// do all processing
		if (downscale8To6Bit) {
			outputStream.write(pcm.to6Bit());
			fileSuffix += ".6bit";
		}
		
		writeFile(outputStream, srcFile, fileSuffix);
		
		return outputStream.toByteArray();
	}

	public static byte[] run() throws Exception {
		
		log.debug("Convert "+MainCommand.IN_FILE_EXT+" PCM data to "+MainCommand.OUT_FILE_EXT+" ...");
		
		// check input file
		File file = new File(filename);
		if (!file.exists()) {
		  String m = "filename: "+filename+" does not exists !";
		  log.error(m);
		  throw new Exception(m);
		}
		
		// all file's processed data will be concatenated and returned to plugin's caller
		ByteArrayOutputStream outputStream = new ByteArrayOutputStream( );
		
		if (!file.isDirectory()) {
			// Single file processing
			outputStream.write(convertFile(file));
		} else {
			// Directory processing
			processDirectory(outputStream, file, MainCommand.IN_FILE_EXT);
		}
		
		log.debug("Conversion ended sucessfully.");

		return outputStream.toByteArray();
	}
		
	private static void processDirectory(ByteArrayOutputStream outputStream, File file, String fileExt) throws Exception {
		
		log.debug("Process each {} file of the directory: {}", fileExt, file.getAbsolutePath());

		File[] files = file.listFiles((d, name) -> name.endsWith(fileExt));
		for (File curFile : files) {
			outputStream.write(convertFile(curFile));
		}
	}
	
	private static void writeFile(ByteArrayOutputStream outputStream, File srcFile, String fileSuffix) throws Exception {
		
		String outFileName;
		
		// output files
		if (genbinary == null || genbinary.equals(""))
		{
			// output is not specified, produce file in same directory as input file
			outFileName = FileUtil.removeExtension(srcFile.getAbsolutePath()) + fileSuffix + MainCommand.OUT_FILE_EXT;
		} else {
			if (Files.isDirectory(Paths.get(genbinary))) {
				// output directory is specified
				outFileName = genbinary + File.separator + FileUtil.removeExtension(srcFile.getName()) + fileSuffix + MainCommand.OUT_FILE_EXT;
			} else {
				// output file is specified
				outFileName = genbinary;
			}
		}
		
		// prevent ouput file to overwrite input file
		if (outFileName != srcFile.getAbsolutePath()) {
			Files.createDirectories(Paths.get(FileUtil.getDir(outFileName)));
			OutputStream fileStream = new FileOutputStream(outFileName);
			outputStream.writeTo(fileStream);
			outputStream.close();
		} else {
			String m = "input and output filename cannot be the same !";
			log.error(m);
			throw new Exception(m);
		}
	}
	
}