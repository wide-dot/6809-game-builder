package com.widedot.toolbox.graphics.png;

import java.io.File;

import lombok.extern.slf4j.Slf4j;
import picocli.CommandLine;
import picocli.CommandLine.ArgGroup;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

/**
 * png to binary converter — the command line over {@link Png2Bin}.
 *
 * The conversion itself lives in Png2Bin, so the builder can ask for the same
 * work through a &lt;png2bin&gt; element without going out to a process.
 */

@Command(name = "png2bin",
         description = "png to binary converter",
		 version="0.0.1",
		 sortOptions = false,
		 mixinStandardHelpOptions = true)
@Slf4j
public class MainCommand implements Runnable {

    @ArgGroup(exclusive = true, multiplicity = "1")
    ExclusiveInputType exclusiveInputType;

    @ArgGroup(exclusive = true, multiplicity = "1")
    ExclusiveOutput exclusiveOutput;

    static class ExclusiveInputType {
            @Option(names = { "-d", "--dir" }, paramLabel = "Input directory", description = "Process all .png files located in the input directory")
            String inputDir;

            @Option(names = { "-f", "--file" }, paramLabel = "Input file", description = "Process .png input file")
            String inputFile;
    }

    @Option(names = { "-lb", "--linearBits" }, required = true, paramLabel = "Linear bits", description = "Number of bits that defines a pixel in a plane")
    private int linearBits = 0;

	@Option(names = { "-pb", "--planarBits" }, paramLabel = "Planar bits", description = "Number of bits to process before going next plane")
    private int planarBits = 0;

	@Option(names = { "-l", "--lineBytes" }, paramLabel = "Line bytes", description = "Number of bytes that defines a line in a plane")
    private int lineBytes = 0;

	@Option(names = { "-p", "--nbPlanes" }, paramLabel = "Number of planes", description = "Number of memory planes")
    private int nbPlanes = 1;

	@Option(names = { "-pd", "--pixelDepth" }, required = true, paramLabel = "Pixel Depth", description = "Number of bits per pixel")
    private int pixelDepth;

	@Option(names = { "-oms", "--out-max-size" }, paramLabel = "Output file max size", description = "Output file maximum size, file will be splitted beyond this value")
	private int fileMaxSize = Integer.MAX_VALUE;

    static class ExclusiveOutput {
	   	@Option(names = { "-vs", "--vertical-scroll" }, paramLabel = "Vertical Scroll Buffer", description = "Output data buffer for Vertical Scroll")
	   	private boolean vscroll = false;

	   	@Option(names = { "-vst", "--vertical-scroll-tile" }, paramLabel = "Vertical Scroll Tile", description = "Output tile data for Vertical Scroll")
	   	private boolean vscrollTile = false;

	   	@Option(names = { "-hs", "--horizontal-scroll" }, paramLabel = "Horizontal Scroll Buffer", description = "Output code buffer for Horizontal Scroll (looping 160px band)")
	   	private boolean hscroll = false;

	   	@Option(names = { "-raw", "--raw" }, paramLabel = "Raw planes", description = "Output the plane binaries only, with no engine buffer on top")
	   	private boolean raw = false;
    }

	@Option(names = { "-slc", "--shiftLeftColors" }, paramLabel = "Shift left colors", description = "Shift colors indexes to the left by one position")
    private boolean shiftLeftColors = false;

	@Option(names = { "-hsc", "--horizontal-scroll-color" }, paramLabel = "Horizontal Scroll guard color", description = "Guard line color for Horizontal Scroll (4 bit pixel value 0-15, after color mapping)")
    private int hscrollGuardColor = 0;

	public static void main(String[] args) {
		CommandLine cmdLine = new CommandLine(new MainCommand());
		System.exit(cmdLine.execute(args));
    }

	@Override
	public void run()
	{
		log.info("png to binary converter");

		Png2Bin.Buffer buffer = Png2Bin.Buffer.NONE;
		if (exclusiveOutput.vscroll)          buffer = Png2Bin.Buffer.VSCROLL;
		else if (exclusiveOutput.vscrollTile) buffer = Png2Bin.Buffer.VSCROLL_TILE;
		else if (exclusiveOutput.hscroll)     buffer = Png2Bin.Buffer.HSCROLL;

		Png2Bin png2bin = new Png2Bin(linearBits, planarBits, lineBytes, nbPlanes, pixelDepth,
		                              fileMaxSize, shiftLeftColors, buffer, hscrollGuardColor);

		File[] files;
		if (exclusiveInputType.inputDir != null) {
			log.info("Process each png file of the directory {}", exclusiveInputType.inputDir);
			File dir = new File(exclusiveInputType.inputDir);
			if (!dir.exists() || !dir.isDirectory()) {
				throw new IllegalArgumentException("input directory does not exist: " + exclusiveInputType.inputDir);
			}
			files = dir.listFiles((d, name) -> name.endsWith(".png"));
		} else {
			log.info("Process {}", exclusiveInputType.inputFile);
			files = new File[] { new File(exclusiveInputType.inputFile) };
		}

		for (File png : files) {
			try {
				png2bin.convert(png);
			} catch (Exception e) {
				// a failed conversion used to be logged and swallowed, which let a
				// build carry on with a missing or stale binary
				throw new RuntimeException("png2bin failed on " + png, e);
			}
		}
	}
}
