package com.widedot.toolbox.audio.vgm2sfx;

import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

@Command(name = "vgm2sfx", description = "Convert one or more .vgm files to .asm sound fx data", sortOptions = false)
public class MainCommand implements Runnable {

	@Option(names = { "-f",
	"--filename" }, required = true, description = "Process an .vgm input file, or all .vgm files in a directory")
	private String filename;

	@Option(names = { "-g",
	"--gensource" }, description = "Output file name (default to filename with specific output extension)")
	private String gensource;
	
	public static void main(String[] args) {
		CommandLine cmdLine = new CommandLine(new MainCommand());
		cmdLine.execute(args);
	}

	@Override
	public void run() {
			try {
				Vgm2SfxPlugin.filename = filename;
				Vgm2SfxPlugin.gensource = gensource; 
				Vgm2SfxPlugin.run();
			} catch (Exception e) {
				e.printStackTrace();
			}
	}
}