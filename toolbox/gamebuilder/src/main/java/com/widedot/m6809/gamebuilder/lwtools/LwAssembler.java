package com.widedot.m6809.gamebuilder.lwtools;

import java.io.File;
import java.lang.reflect.Constructor;
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
public class LwAssembler
{
	
	public static final String BUILD_DIR = ".build";
	
	// format types
	public static final String OBJ  = "obj";
	public static final String DECB = "decb";
	public static final String OS9  = "os9";
	public static final String RAW  = "raw";
	public static final String HEX  = "hex";
	public static final String SREC = "srec";
	public static final String IHEX = "ihex";
	
	// auxiliary output types
	public static final String LST = "lst";
	
	public static final HashMap<String, String> formatClass = new HashMap<String, String>() {
		private static final long serialVersionUID = 1L;
		{
			put(OBJ,  "com.widedot.m6809.gamebuilder.lwtools.format.LwObject");
			put(DECB, "com.widedot.m6809.gamebuilder.lwtools.format.LwRaw");
			put(OS9,  "com.widedot.m6809.gamebuilder.lwtools.format.LwRaw");
			put(RAW,  "com.widedot.m6809.gamebuilder.lwtools.format.LwRaw");
			put(HEX,  "com.widedot.m6809.gamebuilder.lwtools.format.LwRaw");
			put(SREC, "com.widedot.m6809.gamebuilder.lwtools.format.LwRaw");
			put(IHEX, "com.widedot.m6809.gamebuilder.lwtools.format.LwRaw");
		}
	};
	
	public static Object assemble(String asmFile, String rootPath, HashMap<String, String> defines, String format) throws Exception {
		
		Path path = Paths.get(asmFile).toAbsolutePath().normalize();
		String buildDir = FileUtil.getDir(asmFile) + BUILD_DIR + "/";
		String asmBasename = FileUtil.removeExtension(FileUtil.getBasename(asmFile));
		String binFilename = buildDir + asmBasename + "." + format;
		String lstFilename = buildDir + asmBasename + "." + LST;

		Files.createDirectories(Paths.get(buildDir));
		
		File del = new File (binFilename);
		del.delete();
		del = new File (lstFilename);
		del.delete();
	
		List<String> command = new ArrayList<String>(List.of("lwasm.exe",
				   path.toString(),
				   "--format=" + format,
				   "--output=" + binFilename,
				   "--list="   + lstFilename,
				   "--includedir=" + rootPath,
				   "--includedir=" + path.getParent().toString()
				   ));
		
		for (Entry<String, String> define : defines.entrySet()) {
			command.add("--define="+define.getKey()+"="+define.getValue());
		}

		log.debug("{}", command);
		Process p = new ProcessBuilder(command).inheritIO().start();
		int result = p.waitFor();
		if (result != 0) {
			throw new Exception("Build Aborted !");			
		}
        
        Class<?> clazz = Class.forName(formatClass.get(format));
        Constructor<?> ctor = clazz.getConstructor(String.class);
        Object object = ctor.newInstance(new Object[] { binFilename });
        
		return object;
	}

}
