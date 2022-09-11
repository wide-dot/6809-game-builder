package com.widedot.m6809.gamebuilder.builder;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;


import com.widedot.m6809.gamebuilder.MainProg;
import com.widedot.m6809.gamebuilder.tools.AssemblyCompiler;
import com.widedot.m6809.gamebuilder.tools.Target;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class RamLoaderCompiler
{

	public static void compileRAMLoader() throws Exception {
		RamLoaderCompiler.compileRAMLoader(Target.FLOPPY);
		Files.deleteIfExists(Paths.get(Game.generatedCodeDirName + FileNames.FILE_INDEX_FD));
		RamLoaderCompiler.compileRAMLoader(Target.MEGAROM_T2);
		Files.deleteIfExists(Paths.get(Game.generatedCodeDirName + FileNames.FILE_INDEX_T2));
	}

	static void compileRAMLoader(Target target) throws Exception {
		log.info("Compiling RAM Loader {} ...", target);
	
		String ramLoader = (target == Target.FLOPPY) ? BuildDisk.duplicateFile(MainProg.game.engineAsmRAMLoaderFd) : BuildDisk.duplicateFile(MainProg.game.engineAsmRAMLoaderT2);

		AssemblyCompiler.compileRAW(ramLoader, target.ordinal()); // TODO : changer en utilisant réellement l'ENUM
		
		Path binFile = Paths.get(BuildDisk.getBINFileName(ramLoader));
		
		log.info("Loader BIN File : {}", binFile);
		byte[] BINBytes = Files.readAllBytes(binFile);
		byte[] InvBINBytes = new byte[BINBytes.length];
	    int j = 0;
	    
		// Inversion des données par bloc de 7 octets (simplifie la copie par pul/psh au runtime)
		for (int i = BINBytes.length-7; i >= 0; i -= 7) {
			InvBINBytes[j++] = BINBytes[i];			                          
			InvBINBytes[j++] = BINBytes[i+1];
			InvBINBytes[j++] = BINBytes[i+2];
			InvBINBytes[j++] = BINBytes[i+3];
			InvBINBytes[j++] = BINBytes[i+4];
			InvBINBytes[j++] = BINBytes[i+5];
			InvBINBytes[j++] = BINBytes[i+6];
		}
		
		Files.write(binFile, InvBINBytes);
	}

}
