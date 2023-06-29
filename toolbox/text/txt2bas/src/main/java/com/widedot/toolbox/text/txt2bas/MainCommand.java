package com.widedot.toolbox.text.txt2bas;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;

import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;
import picocli.CommandLine;
import picocli.CommandLine.ArgGroup;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

@Command(name = "txt2bas", description = "Convert UTF-8 text file (.txt) to basic langage files (.bas)")
@Slf4j
public class MainCommand implements Runnable {

	@ArgGroup(exclusive = true, multiplicity = "1")
	Exclusive exclusive;

	static class Exclusive {
		@Option(names = { "-d",
				"--dir" }, paramLabel = "Input directory", description = "Process all .txt files located in the input directory")
		String inputDir;

		@Option(names = { "-f", "--file" }, paramLabel = "Input file", description = "Process a text input file")
		String inputFile;
	}

	@Option(names = { "-t",
			"--tokenset" }, paramLabel = "Basic token set", description = "Predifined token set (mo, to (default), nano, coco, dragon)")
	private String tokenset = "to";

	public static void main(String[] args) {
		CommandLine cmdLine = new CommandLine(new MainCommand());
		cmdLine.execute(args);
	}

	@Override
	public void run() {
		
		log.info("Convert ascii text file (.txt) to basic langage files (.bas)");
		
		try {
			HashMap<byte[], byte[]> tokenmap = FileResourcesUtils.getHashMap(tokenset+".def");
		
			if (exclusive.inputFile != null) {
				File txtFile = new File(exclusive.inputFile);
				convert(txtFile, tokenmap);
			} else {
				log.info("Process each .txt file of the directory: {}", exclusive.inputDir);
				File dir = new File(exclusive.inputDir);
				if (!dir.exists() || !dir.isDirectory()) {
					log.error("Input directory does not exists !");
				} else {
					File[] files = dir.listFiles((d, name) -> name.endsWith(".txt"));
					for (File txtFile : files) {
						convert(txtFile, tokenmap);
					}
				}
			}
			log.info("Conversion ended sucessfully.");
		} catch (Exception e) {
			e.printStackTrace();
		}		
	}
	
	private void convert(File file, HashMap<byte[], byte[]> tokenmap) throws Exception {
		String outFileName = FileUtil.removeExtension(file.getAbsolutePath())+AsciiConverter.BASIC_EXT;
		Files.write(Path.of(outFileName), AsciiConverter.getBasic(file, tokenmap));
	}
}