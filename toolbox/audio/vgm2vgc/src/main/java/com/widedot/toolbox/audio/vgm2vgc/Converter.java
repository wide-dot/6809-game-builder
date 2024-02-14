package com.widedot.toolbox.audio.vgm2vgc;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.StringWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import javax.script.ScriptEngineManager;
import javax.script.SimpleScriptContext;

import javax.script.ScriptEngine;
import javax.script.Invocable;
import javax.script.ScriptContext;

import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Converter {

	public static String INPUT_EXT1 = ".vgm";
	public static String INPUT_EXT2 = ".vgz";
	public static String BIN_EXT = ".vgc";

	public static String filename;
	public static String genbinary;

	public static byte[] run() throws Exception {

		log.debug("Convert {} or {} to {}", INPUT_EXT1, INPUT_EXT2, BIN_EXT);
		
		// check input file
		File file = new File(filename);
		if (!file.exists()) {
			String m = "filename: "+filename+" does not exists !";
			log.error(m);
			throw new Exception(m);
		}

		ByteArrayOutputStream outputStream = new ByteArrayOutputStream( );

		if (!file.isDirectory()) {

			// Single file processing
			outputStream.write(convertFile(file));

		} else {

			// Directory processing
			processDirectory(outputStream, file, INPUT_EXT1);
			processDirectory(outputStream, file, INPUT_EXT2);

		}
		log.debug("Conversion ended sucessfully.");

		return outputStream.toByteArray();
	}


	private static void processDirectory(ByteArrayOutputStream outputStream, File file, String fileExt) throws Exception {

		log.debug("Process each {} file of the directory: {}", fileExt, file.getAbsolutePath());

		File[] files = file.listFiles((d, name) -> name.endsWith(fileExt));
		for (File curFile : files) {
			outputStream.write(convertFile(curFile));
		}
	}


	private static byte[] convertFile(File file) throws Exception {

		String outFileName;
		if (genbinary == null || genbinary.equals(""))
		{
			// output is not specified, produce file in same directory as input file
			outFileName = FileUtil.removeExtension(file.getAbsolutePath()) + BIN_EXT;
		} else {
			if (Files.isDirectory(Paths.get(genbinary))) {
				// output directory is specified
				outFileName = genbinary + File.separator + FileUtil.removeExtension(file.getName()) + BIN_EXT;
			} else {
				// output file is specified
				outFileName = genbinary;
			}
		}

		Files.createDirectories(Paths.get(FileUtil.getDir(outFileName)));
		ByteArrayOutputStream finalOS = new ByteArrayOutputStream();
		
		// Keep SN76489 data only
		VGMInterpreter vgm = new VGMInterpreter(file);
		byte[] intro = vgm.getIntroData();
		byte[] loop = vgm.getLoopData();

		if (false && intro != null) {
			ByteArrayOutputStream tmpOS = new ByteArrayOutputStream();
			tmpOS.write(vgm.getIntroHeader());
			tmpOS.write(intro);
			
			String tmpFileName = file.getAbsolutePath() + ".sn76489.intro.vgm";
			OutputStream fileStream = new FileOutputStream(tmpFileName);
			tmpOS.writeTo(fileStream);
			tmpOS.close();
			
			// Convert vgm to vgc
			runPythonScript(tmpFileName, outFileName);
			intro = Files.readAllBytes(Paths.get(outFileName));
			finalOS.write(intro);
		}
		
		if (loop != null) {
			ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
			outputStream.write(vgm.getLoopHeader());
			outputStream.write(loop);
			
			String tmpFileName = file.getAbsolutePath() + ".sn76489.loop.vgm";
			OutputStream fileStream = new FileOutputStream(tmpFileName);
			outputStream.writeTo(fileStream);
			outputStream.close();
			
			// Convert vgm to vgc
			runPythonScript(tmpFileName, outFileName);
			loop = Files.readAllBytes(Paths.get(outFileName));
			finalOS.write(loop);
		}

		OutputStream fileStream = new FileOutputStream(outFileName);
		finalOS.writeTo(fileStream);
		finalOS.close();
		
		return finalOS.toByteArray();
	}

	public static void runPythonScript(String inFileName, String outFileName) throws Exception {

		StringWriter writer = new StringWriter();
		
		try {
			ScriptEngineManager manager = new ScriptEngineManager();
			ScriptContext context = new SimpleScriptContext();
			ScriptEngine engine = manager.getEngineByName("python");
		    Invocable inv = (Invocable) engine;
			
			// share a common context
			context.setWriter(writer);
			engine.setContext(context);
			
			// add jar path to jython sys path
			String jarPath = Converter.class.getProtectionDomain().getCodeSource().getLocation().getPath().toString();
			engine.eval("import sys; sys.path.insert(0, \"" + jarPath + "/vgmpacker" + "\")");
			
			// load script
			InputStreamReader script = new InputStreamReader(Converter.class.getResource("/vgmpacker/vgmpacker.py").openStream());
			engine.eval(script);
			script.close();
			
			// instanciate an object
			Object vgmPacker = engine.eval("VgmPacker()");
			
			// run the method
		    inv.invokeMethod(vgmPacker, "process", inFileName, outFileName, 255, false);
		    
		} finally {
			log.debug(writer.toString());
		}
	}	
}