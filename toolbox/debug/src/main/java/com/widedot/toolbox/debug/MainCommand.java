package com.widedot.toolbox.debug;

import lombok.extern.slf4j.Slf4j;
import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

/**
 * simple tile map to binary converter
 * - extract stm header informations and produce an asm equate file
 * - convert tile id from little endian to big endian
 * - adjust tile id byte depth to desired size
 * - produce a binary file that contains only the tileid
 * - split binary files based on a max size (ex: to fit a memory page)
 */

@Command(name = "wddebug", description = "Debug GUI for Thomson emulators")
@Slf4j
public class MainCommand implements Runnable {

    @Option(names = { "-f", "--file" }, paramLabel = "Input file", description = "Process .stm input file")
    String inputFile;
	
	public static void main(String[] args) {
		CommandLine cmdLine = new CommandLine(new MainCommand());
		cmdLine.execute(args);
    }

	@Override
	public void run()
	{
		log.info("Debug GUI for Thomson emulators");
		
		log.info("Load symbols <"+inputFile+">");
		Symbols s = new Symbols(inputFile);
		
		log.info("Launch GUI");
		new WDDebug(s);
	}

}