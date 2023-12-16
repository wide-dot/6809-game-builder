package com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools;

import java.io.File;
import java.io.IOException;
import java.lang.reflect.Constructor;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map.Entry;

import org.apache.commons.io.FileUtils;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.m6809.util.Constants;
import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class LwAssembler
{
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
	public static final String LWMAP = "lwmap";
	
	public static final HashMap<String, String> formatClass = new HashMap<String, String>() {
		private static final long serialVersionUID = 1L;
		{
			put(OBJ,  "com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format.LwObject");
			put(DECB, "com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format.LwRaw");
			put(OS9,  "com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format.LwRaw");
			put(RAW,  "com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format.LwRaw");
			put(HEX,  "com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format.LwRaw");
			put(SREC, "com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format.LwRaw");
			put(IHEX, "com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format.LwRaw");
		}
	};
	
	public static ObjectDataInterface assemble(String asmFile, String rootPath, Defines defines, String format, String processor) throws Exception {
		
		Path path = Paths.get(asmFile).toAbsolutePath().normalize();
		String buildDir = FileUtil.getDir(asmFile) + File.separator +Settings.values.get("build.dir") + File.separator;
		String asmBasename = FileUtil.removeExtension(FileUtil.getBasename(asmFile));
		String binFilename = buildDir + asmBasename + "." + format;
		String lstFilename = buildDir + asmBasename + "." + LST;
		String mapFilename = buildDir + asmBasename + "." + LWMAP;

		Files.createDirectories(Paths.get(buildDir));
		
		File del = new File (binFilename);
		del.delete();
		del = new File (lstFilename);
		del.delete();
		del = new File (mapFilename);
		del.delete();
	
		List<String> command = new ArrayList<String>(List.of("lwasm.exe",
				   path.toString(),
				   "--" + processor,
				   "--format=" + format,
				   "--output=" + binFilename,
				   "--list="   + lstFilename,
				   "--includedir=" + rootPath,
				   "--includedir=" + path.getParent().toString(),
				   "--map=" + mapFilename
				   ));
		
		for (Entry<String, String> define : defines.values.entrySet()) {
			String val = define.getValue();
			if (val.startsWith("$")) {
				command.add("--define="+define.getKey()+"="+Integer.parseInt(val.substring(1),16));
			} else {
				command.add("--define="+define.getKey()+"="+define.getValue());
			}
		}

		log.debug("{}", command);
		Process p = new ProcessBuilder(command).inheritIO().start();
		int result = p.waitFor();
		if (result != 0) {
			throw new Exception("Build Aborted !");			
		}
        
        Class<?> clazz = Class.forName(formatClass.get(format));
        Constructor<?> ctor = clazz.getConstructor(String.class);
        ObjectDataInterface object = (ObjectDataInterface) ctor.newInstance(new Object[] { binFilename });
        
        // export builder defines
        String defineKey = Constants.BUILDER_DEFINE_PREFIX + "lwasm.size." + asmBasename;
        String binLength = Integer.toString(object.getBytes().length);
        
        if (defines.values.containsKey(defineKey)) {
        	log.warn("Duplicate filename: <" + asmBasename + ">. Builder will overwrite the define: <" + defineKey + ">. Use gensource attribute on lwasm element to set an alias");
        }

        defines.newValues.put(defineKey, binLength);
        log.debug("generate define : {} {}", defineKey,  binLength);
        
        // add a file tag in the build directory
        File tag = new File(buildDir+Settings.values.get("build.dir.tag"));
        tag.createNewFile();
        
		return object;
	}
	
	public static void clean(String path) throws IOException {
		log.info("Clean build directories ...");	   
	    deleteDirectoryRecursion(Paths.get(path));
	    log.info("Clean ended.");
	}
	
	public static void deleteDirectoryRecursion(Path path) throws IOException {
		if (Files.isDirectory(path, LinkOption.NOFOLLOW_LINKS)) {
			
			// only delete the directory that ends with the expected name
			if (path.getFileName().toString().equals(Settings.values.get("build.dir"))) {
				
				// to ensure that the directory is a one created by the builder, a file tag is controlled
				File tag = new File(path.toString()+File.separator+Settings.values.get("build.dir.tag"));
				if (tag.isFile()) {
					log.debug("delete: {}", path.toString());
					FileUtils.deleteDirectory(path.toFile());
				} else {
					log.warn("cancel deletion of: {} - tag: {} not found", path.toString(), tag.toString());
				}
				
			} else {
				try (DirectoryStream<Path> entries = Files.newDirectoryStream(path)) {
					for (Path entry : entries) {
						deleteDirectoryRecursion(entry);
					}
				}
			}
		}
	}
}
