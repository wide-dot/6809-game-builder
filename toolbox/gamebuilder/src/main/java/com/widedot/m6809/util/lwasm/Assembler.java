package com.widedot.m6809.util.lwasm;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map.Entry;

import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Assembler
{
	
	public static final String BUILD_DIR = ".build";
	
	public static void process(String asmFile, String rootPath, HashMap<String, String> defines) throws Exception {
		Path path = Paths.get(asmFile).toAbsolutePath().normalize();
		String buildDir = FileUtil.getDir(asmFile) + BUILD_DIR + "/";
		String asmBasename = FileUtil.removeExtension(FileUtil.getBasename(asmFile));
		String binFilename = buildDir + asmBasename + ".bin";
		String lstFilename = buildDir + asmBasename + ".lst";

		Files.createDirectories(Paths.get(buildDir));
		
		File del = new File (binFilename);
		del.delete();
		del = new File (lstFilename);
		del.delete();
	
		log.debug("Assembling {} ",path.toString());
		
		// TODO apply section as a parameter
		//SECTION
		//ENDSECTION
		
		List<String> command = new ArrayList<String>(List.of("lwasm.exe", //TODO make a global value
				   path.toString(),
				   "--output=" + binFilename,
				   "--list=" + lstFilename,
				   "--6809",
				   "--includedir="+rootPath,
				   "--includedir="+path.getParent().toString()
				   ));
		
		for (Entry<String, String> define : defines.entrySet()) {
			command.add("--define="+define.getKey()+"="+define.getValue());
		}

		log.debug("Command : {}", command);
		Process p = new ProcessBuilder(command).inheritIO().start();
	}

}
