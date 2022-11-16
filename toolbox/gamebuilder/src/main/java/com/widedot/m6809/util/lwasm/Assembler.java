package com.widedot.m6809.util.lwasm;

import java.io.File;
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
	public static void process(String asmFile, HashMap<String, String> defines) throws Exception {
		Path path = Paths.get(asmFile).toAbsolutePath().normalize();
		String asmFileName = FileUtil.removeExtension(asmFile);
		String binFile = asmFileName + ".bin";
		String lstFile = asmFileName + ".lst";
		
		File del = new File (binFile);
		del.delete();
		del = new File (lstFile);
		del.delete();
	
		log.info("Compiling {} ",path.toString());
		
		// TODO apply section as a parameter
		//SECTION
		//ENDSECTION
		
		List<String> command = new ArrayList<String>(List.of("lwasm.exe", //TODO make a global value
				   path.toString(),
				   "--obj",
				   "--output=" + binFile,
				   "--list=" + lstFile,
				   "--6809",
				   "--pragma=undefextern",
				   "--includedir="+path.getParent().toString(),
				   "--includedir=C:/Users/Public/Documents/6809-game-builder/sonic2"
				   ));
		
		for (Entry<String, String> define : defines.entrySet()) {
			command.add("--define="+define.getKey()+"="+define.getValue());
		}

		log.debug("Command : {}", command);
		Process p = new ProcessBuilder(command).inheritIO().start();
	}

}
