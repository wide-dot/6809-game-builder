package com.widedot.toolbox.debug;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.stream.Stream;

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

    @Option(names = { "-d", "--dir" }, paramLabel = "Input directory for .lwmap files", description = "Process all .lwmap files located in the directory and sub directories")
    String inputDir;

    @Option(names = { "-f", "--file" }, paramLabel = "Input .lwmap file(s) separated by semicolon", description = "Process .lwmap input files")
    String inputFile;
    
	public static void main(String[] args) {
		CommandLine cmdLine = new CommandLine(new MainCommand());
		cmdLine.execute(args);
    }

	@Override
	public void run()
	{
		log.info("Debug GUI for Thomson emulators");
		
		// search for map files in input directory
		if (inputDir != null) {
			try (Stream<Path> walkStream = Files.walk(Paths.get(inputDir))) {
			    walkStream.filter(p -> p.toFile().isFile()).forEach(f -> {
			        if (f.toString().endsWith(".lwmap")) {
						log.info("Load symbols <"+f.toString()+">");
			        	Symbols.addMap(f.toString());
			        }
			    });
			} catch(Exception e) {
				log.error("Error reading directory "+inputDir);
			}
		}

		// load .lwmap files
		if (inputFile != null) {
			String[] files = inputFile.split(";");
			for (int i = 0; i < files.length; i++) {
				log.info("Load symbols <"+files[i]+">");
				Symbols.addMap(files[i]);
			}
		}
		
		log.info("Launch GUI");
		new WDDebug();
	}

}