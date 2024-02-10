package com.widedot.toolbox.audio.vgm2vgc;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.nio.file.Files;
import java.nio.file.Paths;

import javax.script.ScriptEngineFactory;
import javax.script.ScriptEngineManager;

import java.util.List;

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

		// Process
		runPythonScript(file);

		ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
		//outputStream.write(bin);

		//OutputStream fileStream = new FileOutputStream(outFileName);
		//outputStream.writeTo(fileStream);

		return outputStream.toByteArray();
	}

	public static void runPythonScript(File file) throws Exception {
		ScriptEngineManager mgr = new ScriptEngineManager();
		List<ScriptEngineFactory> factories = mgr.getEngineFactories();
		for (ScriptEngineFactory factory : factories) {
			System.out.println("ScriptEngineFactory Info");
			String engName = factory.getEngineName();
			String engVersion = factory.getEngineVersion();
			String langName = factory.getLanguageName();
			String langVersion = factory.getLanguageVersion();
			System.out.printf("\tScript Engine: %s (%s)\n", engName, engVersion);
			List<String> engNames = factory.getNames();
			for (String name : engNames) {
				System.out.printf("\tEngine Alias: %s\n", name);
			}
			System.out.printf("\tLanguage: %s (%s)\n", langName, langVersion);
		}
//		StringWriter writer = new StringWriter();
//		ScriptContext context = new SimpleScriptContext();
//		context.setWriter(writer);
//
//		ScriptEngineManager manager = new ScriptEngineManager();
//		ScriptEngine engine = manager.getEngineByName("python");
//		engine.eval(new FileReader(Converter.class.getResource("vgm-packer/vgmpacker.py").getPath()), context);
//		log.debug(writer.toString());
	}	
}