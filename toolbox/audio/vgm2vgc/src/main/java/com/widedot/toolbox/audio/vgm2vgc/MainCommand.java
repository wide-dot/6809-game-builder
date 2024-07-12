package com.widedot.toolbox.audio.vgm2vgc;

import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

@Command(name = "vgm2vgc", description = "Convert one or more .vgm files to .ymm binary data", sortOptions = false)
public class MainCommand implements Runnable {

	@Option(names = { "-f",
	"--filename" }, required = true, description = "Process an .vgm input file, or all .vgm files in a directory")
	private String filename;

	@Option(names = { "-c",
	"--codec" }, description = "Codec (none (default), zx0)")
	private String codec = null;
	
	@Option(names = { "-d",
	"--dac2drum" }, paramLabel = "Remap DAC with YM2413 Drum", description = "Remap DAC samples with YM2413 drum.\nParameters are drum values for each dac sample id.\nex: 0x30,0x28,0x21,0x22,0x24\nWhere DAC sample Id 0 is replaced by a YM2413 drum instrument 0x30\n")
    String drum = null;

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
				Vgm2VgcPlugin.filename = filename;
				Vgm2VgcPlugin.genbinary = genbinary; 
				Vgm2VgcPlugin.run();
			} catch (Exception e) {
				e.printStackTrace();
			}
	}
}