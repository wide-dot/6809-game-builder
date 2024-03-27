package com.widedot.toolbox.audio.pcm;

import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

/**
 * PCM toolbox
 */

@Command(name = "pcm", description = "Toolbox for pcm binary data")
public class MainCommand implements Runnable {
	
    public static final String IN_FILE_EXT = ".raw";
    public static final String OUT_FILE_EXT = ".bin";

	@Option(names = { "-f", "--filename" }, required = true, description = "Process an "+IN_FILE_EXT+" input file, or all "+IN_FILE_EXT+" files in a directory and produce "+OUT_FILE_EXT+" files")
	private String filename;

	@Option(names = { "-8to6", "--bit8to6" }, paramLabel = "8bit to 6bit output downscale", description = "While keeping 8byte for each sample, will downscale sample value to 6bit")
    private boolean downscale8To6Bit = false;
	
	@Option(names = { "-g", "--genbinary" }, description = "Output file name (default to filename with specific mode extension)")
	private String genbinary;
	
	public static void main(String[] args) {
		CommandLine cmdLine = new CommandLine(new MainCommand());
		cmdLine.execute(args);
	}

	@Override
	public void run()
	{
		try {
			Converter.filename = filename;
			Converter.genbinary = genbinary; 
			Converter.downscale8To6Bit = downscale8To6Bit;
			Converter.run();
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}