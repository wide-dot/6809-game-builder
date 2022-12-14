package com.widedot.toolbox.audio.svgm;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;

import lombok.extern.slf4j.Slf4j;
import picocli.CommandLine;
import picocli.CommandLine.ArgGroup;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

@Command(name = "svgm", description = "small vgm converter")
@Slf4j
public class MainCommand implements Runnable {
	
    @ArgGroup(exclusive = true, multiplicity = "1")
    Exclusive exclusive;

    static class Exclusive {
            @Option(names = { "-d", "--dir" }, paramLabel = "Input directory", description = "Process all .vgm files located in the input directory")
            String inputDir;

            @Option(names = { "-f", "--file" }, paramLabel = "Input file", description = "Process .vgm input file")
            String inputFile;
    }

    @Option(names = { "-c", "--compress" }, paramLabel = "Compress svgm stream", description = "Compress svgm stream by chips and channels\n")
    Boolean compress = false;
        
	@Option(names = { "-da", "--drumatt" }, paramLabel = "Drum attenuation remap", description = "Remap YM2413 drum attenuation to given values.\nex: 0xF2,0x62,0x44\nwhere each nibble is 0: max vol, F: silence\n0xF2 : F (unused) 2 (attenuation value for Bass drum)\n0x62 : 6 (attenuation value for Hi-hat) 2 (attenuation value for Snare drum)\n0x44 : 4 (attenuation value for Tom) 4 (attenuation value for Cymbal)\n")
    String drumAttStr = null;
	
	@Option(names = { "-rd", "--remapdac" }, paramLabel = "Remap DAC with YM2413 Drum", description = "Remap DAC samples with YM2413 drum.\nParameters are drum values for each dac sample id.\nex: 0x30,0x28,0x21,0x22,0x24\nWhere DAC sample Id 0 is replaced by a YM2413 drum instrument 0x30\n")
    String drumStr = null;
	
    @Option(names = { "-v", "--verbose"}, description = "Verbose mode. Helpful for troubleshooting.")
    private boolean verbose = false;

	public static void main(String[] args) {
		CommandLine cmdLine = new CommandLine(new MainCommand());
		cmdLine.execute(args);
    }
	
	public static String outputFilename;
	public static int[] drumAtt;
	public static int[] drum;

	@Override
	public void run()
	{
		log.info("Simple Tile Map to binary converter");

		if (drumAttStr != null) {
			String[] attValues = drumAttStr.split(",");
			if (attValues.length != 3) {
				log.error("drumatt option need three arguments, ex: 0xF2,0x62,0x44");
				return;
			}
			drumAtt = new int[3];
			drumAtt[0] = Integer.decode(attValues[0]);
			drumAtt[1] = Integer.decode(attValues[1]);
			drumAtt[2] = Integer.decode(attValues[2]);
		}
		
		if (drumStr != null) {
			String[] drumValues = drumStr.split(",");
			drum = new int[3];
			drum[0] = Integer.decode(drumValues[0]);
			drum[1] = Integer.decode(drumValues[1]);
			drum[2] = Integer.decode(drumValues[2]);
		}

        if (exclusive.inputDir != null) {
		log.info("Process each stm file of the directory {}", exclusive.inputDir);

                // process each stm file of the directory		
                File dir = new File(exclusive.inputDir);
                if (!dir.exists() || !dir.isDirectory()) {
                	log.error("Input directory does not exists !");
                } else {	
                	File[] files = dir.listFiles((d, name) -> name.endsWith(".stm"));
                	for (File stmFile : files) {
                		String fileName = stmFile.getAbsolutePath();
            			if (fileName.endsWith(".vgm")) {
            				outputFilename = fileName.replace(".vgm", ".svgm");
            			} else {
            				outputFilename = fileName + ".svgm";
            			}  
            			convertFile(stmFile, compress);
                	}
                }
        } else {
			if (exclusive.inputFile.endsWith(".vgm")) {
				outputFilename = exclusive.inputFile.replace(".vgm", ".svgm");
			} else {
				outputFilename = exclusive.inputFile + ".svgm";
			}  
			convertFile(new File(exclusive.inputFile), compress);
        }
        log.info("Done.");
	}

	private static void convertFile(File paramFile, Boolean compress) {
		VGMInterpreter vGMInterpreter;
		try {
			if (compress==false) {
				vGMInterpreter = new VGMInterpreter(paramFile, drumAtt, drum, VGMInterpreter._ALL, VGMInterpreter._ALL);
				vGMInterpreter.close();
				exportSound(vGMInterpreter, new File(outputFilename));
			} else {
				for (int i=0; i<=3; i++) {
					vGMInterpreter = new VGMInterpreter(paramFile, drumAtt, drum, VGMInterpreter._SN76489, i);
					vGMInterpreter.close();
					exportSound(vGMInterpreter, new File(outputFilename+"."+VGMInterpreter._SN76489+"_"+i));
				}
				
				for (int i=0; i<=9; i++) {
					vGMInterpreter = new VGMInterpreter(paramFile, drumAtt, drum, VGMInterpreter._YM2413, i);
					vGMInterpreter.close();
					exportSound(vGMInterpreter, new File(outputFilename+"."+VGMInterpreter._YM2413+"_"+i));
				}
					
			}
		} catch (IOException iOException) {
			iOException.printStackTrace();
		} 
	}

	private static void exportSound(VGMInterpreter vGMInterpreter, File paramFile) {
		try {
			int[] paramArrayOfint = vGMInterpreter.getArrayOfInt();
			FileOutputStream fileOutputStream = new FileOutputStream(paramFile);
			byte[] arrayOfByte = new byte[vGMInterpreter.getLastIndex()];
			for (int b = 0; b < vGMInterpreter.getLastIndex(); b++)
				arrayOfByte[b] = (byte)paramArrayOfint[b]; 
			fileOutputStream.write(arrayOfByte);
			fileOutputStream.close();
		} catch (IOException iOException) {
			iOException.printStackTrace();
		} 
	}

}