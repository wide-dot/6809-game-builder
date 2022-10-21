package com.widedot.toolbox.graphics.tilemap.stm;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileWriter;

import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;
import picocli.CommandLine;
import picocli.CommandLine.ArgGroup;
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

@Command(name = "stm2bin", description = "simple tile map to binary converter")
@Slf4j
public class MainCommand implements Runnable {
	
        @ArgGroup(exclusive = true, multiplicity = "1")
        Exclusive exclusive;

        static class Exclusive {
                @Option(names = { "-d", "--dir" }, paramLabel = "Input directory", description = "Process all .stm files located in the input directory")
                String inputDir;

                @Option(names = { "-f", "--file" }, paramLabel = "Input file", description = "Process .stm input file")
                String inputFile;
        }

	@Option(names = { "-ibd", "--in-byte-depth" }, paramLabel = "Input byte depth", description = "Input file byte depth for a tile id")
        private int inByteDepth = 4;

	@Option(names = { "-obd", "--out-byte-depth" }, paramLabel = "Output byte depth", description = "Output file byte depth for a tile id")
        private int outByteDepth = 2;

	@Option(names = { "-oms", "--out-max-size" }, paramLabel = "Output file max size", description = "Output file maximum size, file will be splitted beyond this value")
	private int fileMaxSize = 16384;

	public static void main(String[] args) {
		CommandLine cmdLine = new CommandLine(new MainCommand());
		cmdLine.execute(args);
    }

	@Override
	public void run()
	{
		log.info("Simple Tile Map to binary converter");

                if (exclusive.inputDir != null) {
        		log.info("Process each stm file of the directory {}", exclusive.inputDir);

                        // process each stm file of the directory		
                        File dir = new File(exclusive.inputDir);
                        if (!dir.exists() || !dir.isDirectory()) {
                        	log.error("Input directory does not exists !");
                        } else {	
                        	File[] files = dir.listFiles((d, name) -> name.endsWith(".stm"));
                        	for (File stmFile : files) {
                        		try {
                        			stmConverter(stmFile, inByteDepth, outByteDepth, fileMaxSize);
                        		} catch (Exception e) {
                        			log.error("Error converting .stm file");
                        		}
                        	}
                        }
                } else {
                        log.info("Process {}", exclusive.inputFile);

                        // process a single stm file
                        File stmFile = new File(exclusive.inputFile);
                        if(!stmFile.exists() || stmFile.isDirectory()) { 
                        	log.error("Input file does not exists !");
                        } else {
                        	try {
                        		stmConverter(stmFile, inByteDepth, outByteDepth, fileMaxSize);
                        	} catch (Exception e) {
                    			log.error("Error converting .stm file");
                    		}
                        }
                }
	}

	private void stmConverter(File paramFile, int inByteDepth, int outByteDepth, int fileMaxSize) throws Exception {

		SimpleTileMap stm = new SimpleTileMap(paramFile, inByteDepth, outByteDepth);

		// split data into multiple files that are maximum fileMaxSize long
		int readIdx = 0;
		int writeIdx = 0;
		int fileId = 0;
		while (readIdx < stm.data.length) {
			FileOutputStream fis = new FileOutputStream(new File(FileUtil.removeExtension(paramFile.toString()) + "." + fileId + ".bin"));
			byte[] finalArray = new byte[(stm.data.length-readIdx<fileMaxSize?stm.data.length-readIdx:fileMaxSize)];
			writeIdx = 0;
			while (readIdx < stm.data.length && writeIdx < fileMaxSize) {
				finalArray[writeIdx++] = stm.data[readIdx++];
			}
			fis.write(finalArray);
			fis.close();
			fileId++;
		}

		// generate equate file with heigth, width and bit depth
		String pathNoExt = FileUtil.removeExtension(paramFile.toString());
		String basename = FileUtil.basename(pathNoExt);
		
		FileWriter writer = new FileWriter(pathNoExt + ".equ", false);
		BufferedWriter bufferedWriter = new BufferedWriter(writer);
		
		bufferedWriter.write(basename+".width equ " + stm.width);
		bufferedWriter.newLine();
		bufferedWriter.write(basename+".height equ " + stm.height);
		bufferedWriter.newLine();
		bufferedWriter.write(basename+".bytedepth equ " + outByteDepth);
		bufferedWriter.newLine();
		bufferedWriter.close();
	}
}