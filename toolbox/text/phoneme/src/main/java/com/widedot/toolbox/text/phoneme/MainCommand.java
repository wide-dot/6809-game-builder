package com.widedot.toolbox.text.phoneme;

import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

@Command(name = "phoneme", description = "Convert UTF-8 text file (.txt) to MEA8000 phonemes (.asm)")

public class MainCommand implements Runnable {

	public static final String IN_FILE_EXT = ".txt";
	public static final String OUT_FILE_EXT = ".asm";

	@Option(names = { "-f", "--filename" }, required = true, description = "Process an " + IN_FILE_EXT
			+ " input file, or all " + IN_FILE_EXT + " files in a directory and produce " + OUT_FILE_EXT + " files")
	private String filename;

	@Option(names = { "-l", "--lang" }, description = "language code (default: fr)")
	private String lang = "fr";

	@Option(names = { "-g",
			"--genbinary" }, description = "Output file name (default to filename with specific mode extension)")
	private String genbinary;

	public static void main(String[] args) {
		CommandLine cmdLine = new CommandLine(new MainCommand());
		cmdLine.execute(args);
	}

	@Override
	public void run() {
		try {
			PhonemePlugin.filename = filename;
			PhonemePlugin.genbinary = genbinary;
			PhonemePlugin.lang = lang;
			PhonemePlugin.run();
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
