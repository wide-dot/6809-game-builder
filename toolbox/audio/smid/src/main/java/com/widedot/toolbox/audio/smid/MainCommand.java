package com.widedot.toolbox.audio.smid;

import java.io.File;

import lombok.extern.slf4j.Slf4j;
import picocli.CommandLine;
import picocli.CommandLine.ArgGroup;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

/**
 * midi to simple midi converter
 * - change midi time management to frame (1/50hz) steps
 * - convert gm to mt32 programms (option)
 */

@Command(name = "smid", description = "midi to simple midi converter")
@Slf4j
public class MainCommand implements Runnable {
	
        @ArgGroup(exclusive = true, multiplicity = "1")
        Exclusive exclusive;

        static class Exclusive {
                @Option(names = { "-d", "--dir" }, paramLabel = "Input directory", description = "Process all .mid files located in the input directory")
                String inputDir;

                @Option(names = { "-f", "--file" }, paramLabel = "Input file", description = "Process .mid input file")
                String inputFile;
        }

	@Option(names = { "-r", "--remap" }, paramLabel = "format ", description = "Remap GM instruments to another format (MT : Roland MT-32)")
        String remap = "";
	
    @Option(names = { "-v", "--verbose"}, description = "Verbose mode. Helpful for troubleshooting.")
    private boolean verbose = false;

	public static void main(String[] args) {
		CommandLine cmdLine = new CommandLine(new MainCommand());
		cmdLine.execute(args);
    }

	@Override
	public void run()
	{
		// verbose mode
	    ch.qos.logback.classic.Logger root = (ch.qos.logback.classic.Logger) org.slf4j.LoggerFactory.getLogger(ch.qos.logback.classic.Logger.ROOT_LOGGER_NAME);
		if (verbose) {
		    root.setLevel(ch.qos.logback.classic.Level.DEBUG);
		} else {
			root.setLevel(ch.qos.logback.classic.Level.INFO);
		}

		log.info("midi to simple midi converter");
		
                if (exclusive.inputDir != null) {
        		log.info("Process each midi file of the directory {}", exclusive.inputDir);

                        // process each stm file of the directory		
                        File dir = new File(exclusive.inputDir);
                        if (!dir.exists() || !dir.isDirectory()) {
                        	log.error("Input directory does not exists !");
                        } else {	
                        	File[] files = dir.listFiles((d, name) -> name.endsWith(".mid"));
                        	for (File midiFile : files) {
                        		try {
                        			new MidiConverter(midiFile, remap);
                        		} catch (Exception e) {
                        			log.error("Error converting .mid file");
                        		}
                        	}
                        }
                } else {
                        // process a single midi file
                        File midiFile = new File(exclusive.inputFile);
                        if(!midiFile.exists() || midiFile.isDirectory()) { 
                        	log.error("Input file does not exists !");
                        } else {
                        	try {
                    			new MidiConverter(midiFile, remap);
                        	} catch (Exception e) {
                    			log.error("Error converting .mid file");
                    		}
                        }
                }
	}
}