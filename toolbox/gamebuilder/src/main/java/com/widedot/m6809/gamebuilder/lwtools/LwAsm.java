package com.widedot.m6809.gamebuilder.lwtools;

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
public class LwAsm
{
	
	public static final String BUILD_DIR = ".build";
	
	public static LwObj makeObject(String asmFile, String rootPath, HashMap<String, String> defines) throws Exception {
		String objectFileName = assemble(asmFile, rootPath, defines, ".o", true);
		return new LwObj(objectFileName);
	}
	
	public static String makeBinary(String asmFile, String rootPath, HashMap<String, String> defines) throws Exception {
		return assemble(asmFile, rootPath, defines, ".bin", false);
	}
	
	public static String assemble(String asmFile, String rootPath, HashMap<String, String> defines, String ext, boolean object) throws Exception {
		Path path = Paths.get(asmFile).toAbsolutePath().normalize();
		String buildDir = FileUtil.getDir(asmFile) + BUILD_DIR + "/";
		String asmBasename = FileUtil.removeExtension(FileUtil.getBasename(asmFile));
		String binFilename = buildDir + asmBasename + ext;
		String lstFilename = buildDir + asmBasename + ".lst";

		Files.createDirectories(Paths.get(buildDir));
		
		File del = new File (binFilename);
		del.delete();
		del = new File (lstFilename);
		del.delete();
	
		List<String> command = new ArrayList<String>(List.of("lwasm.exe",
				   path.toString(),
				   "--format="+(object?"obj":"raw"),
				   "--output=" + binFilename,
				   "--list=" + lstFilename,
				   "--includedir="+rootPath,
				   "--includedir="+path.getParent().toString()
				   ));
		
		for (Entry<String, String> define : defines.entrySet()) {
			command.add("--define="+define.getKey()+"="+define.getValue());
		}

		log.debug((object?"OBJ":"RAW") + " - {}", command);
		Process p = new ProcessBuilder(command).inheritIO().start();
		int result = p.waitFor();
		if (result != 0) {
			throw new Exception("Build Aborted !");			
		}
		return binFilename;
	}

}
