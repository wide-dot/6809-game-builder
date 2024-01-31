package com.widedot.toolbox.graphics.png2pal;

import picocli.CommandLine;
import picocli.CommandLine.ArgGroup;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

@Command(name = "png2pal", description = "Convert an image file (.png) to palette data in an assembly file (.asm)")
public class MainCommand implements Runnable {

	@ArgGroup(exclusive = true, multiplicity = "1")
	Exclusive exclusive;

	static class Exclusive {
		@Option(names = { "-d",
				"--dir" }, paramLabel = "Input directory", description = "Process all .txt files located in the input directory")
		String dirname;

		@Option(names = { "-f", "--file" }, paramLabel = "Input file", description = "Process a text input file")
		String filename;
	}

	@Option(names = { "-m",
	"--mode" }, paramLabel = "Mode", description = "Conversion mode (obj (default), dat, bin")
	private String mode = Converter.OBJ;
	
	@Option(names = { "-p",
			"--profile" }, paramLabel = "Profile name", description = "Color profile (to (default))")
	private String profile = "to";
	
	@Option(names = { "-s",
	"--symbol" }, paramLabel = "Symbol name", description = "Symbol name in asm (default to filename)")
	private String symbol;

	@Option(names = { "-g",
	"--gensource" }, paramLabel = "Output file", description = "Output asm file name (default to input filename with .asm ext)")
	private String gensource;
	
	@Option(names = { "-c",
	"--colors" }, paramLabel = "Nb of colors", description = "Number of converted colors (default to 16)")
	private int colors=16;
	
	@Option(names = { "-o",
	"--offset" }, paramLabel = "Color index offset", description = "Color index offset, determines the starting color index (default to 1, index 0 is gennarally assigned to transparent color)")
	private int offset=1;
	
	public static void main(String[] args) {
		CommandLine cmdLine = new CommandLine(new MainCommand());
		cmdLine.execute(args);
	}

	@Override
	public void run() {
			Converter.run(symbol, mode, colors, offset, profile, exclusive.filename, exclusive.dirname, gensource);
	}
}