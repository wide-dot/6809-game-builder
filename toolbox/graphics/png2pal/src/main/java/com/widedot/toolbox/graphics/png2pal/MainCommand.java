package com.widedot.toolbox.graphics.png2pal;

import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

@Command(name = "png2pal", description = "Process one or more PNG files to extract and convert indexed palette data", sortOptions = false)
public class MainCommand implements Runnable {

	@Option(names = { "-f",
	"--filename" }, required = true, description = "Process a png input file, or all png files in a directory")
	private String filename;

	@Option(names = { "-m",
	"--mode" }, description = "Conversion mode (obj (default), dat, bin)")
	private String mode = Png2PalPlugin.OBJ;
	
	@Option(names = { "-p",
	"--profile" }, description = "Color profile (to (default))")
	private String profile = "to";
	
	@Option(names = { "-o",
	"--offset" }, description = "Color index offset, determines the starting color index (default to 1, index 0 is gennarally assigned to transparent color)")
	private int offset=1;
	
	@Option(names = { "-c",
	"--colors" }, description = "Number of converted colors (default to 16)")
	private int colors=16;

		@Option(names = { "-s",
	"--symbol" }, description = "Symbol name in asm (default to filename minus extension)")
	private String symbol;

	@Option(names = { "-g",
	"--gensource" }, description = "Output asm file name (default to filename with specific mode extension)")
	private String gensource;
	
	public static void main(String[] args) {
		CommandLine cmdLine = new CommandLine(new MainCommand());
		cmdLine.execute(args);
	}

	@Override
	public void run() {
			try {
				Png2PalPlugin.run(symbol, mode, colors, offset, profile, filename, gensource);
			} catch (Exception e) {
				e.printStackTrace();
			}
	}
}