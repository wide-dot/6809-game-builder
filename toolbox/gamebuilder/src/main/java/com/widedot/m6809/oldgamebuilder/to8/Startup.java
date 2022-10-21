package com.widedot.m6809.oldgamebuilder.to8;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;

import com.widedot.m6809.oldgamebuilder.to8.Startup;
import com.widedot.m6809.oldgamebuilder.to8.builder.BuildDisk;
import com.widedot.m6809.oldgamebuilder.to8.builder.Game;

import lombok.extern.slf4j.Slf4j;
import net.lingala.zip4j.io.inputstream.ZipInputStream;
import net.lingala.zip4j.model.LocalFileHeader;

@Slf4j
public class Startup
{
	public static final String TMP_DIR = "./_tmp";	
	public static final Path TMP_DIR_PATH = Path.of(TMP_DIR).normalize().toAbsolutePath();
	
	private Startup()
	{
		// hidding constructor for this instanceless class, to prevent useless instanciation.
	}

	public static void showSplash() throws IOException
	{
		InputStream stream = Startup.class.getResourceAsStream("/splash.txt");
		IOUtils.copy(stream, System.out);		
	}

	public static void createTemporaryDirectory(boolean erase) throws IOException
	{
		if (erase)
		{
			log.info("Erasing existing temporary directory : {} ", TMP_DIR_PATH);
			FileUtils.deleteDirectory(TMP_DIR_PATH.toFile());
		}
		Files.createDirectories(TMP_DIR_PATH);
	}

	public static void extractResource(String resourceName, boolean executable) throws IOException
	{
		InputStream toolsStream = Startup.class.getResourceAsStream(resourceName);
		log.info("Extracting {} in {}", resourceName, TMP_DIR_PATH);

		try (ZipInputStream zipInputStream = new ZipInputStream(toolsStream))
		{
			LocalFileHeader localFileHeader;
			while ((localFileHeader = zipInputStream.getNextEntry()) != null)
			{
				Path extractedPath = Path.of(TMP_DIR, localFileHeader.getFileName());
				Startup.extractFile(executable, zipInputStream, localFileHeader, extractedPath);
			}
		}
	}
	
	private static void extractFile(boolean executable, ZipInputStream zipInputStream, LocalFileHeader localFileHeader, Path extractedPath) throws IOException
	{
		if (localFileHeader.isDirectory())
		{
			Files.createDirectories(extractedPath);
		}
		else
		{
			Files.copy(zipInputStream, extractedPath);
			extractedPath.toFile().setExecutable(executable);
		}
	}

	public static void clean() throws IOException {
		log.info("Delete RAM data files ...");
	
		File file = new File (Game.generatedCodeDirName+"RAM data/"+BuildDisk.MODE_LABEL[BuildDisk.FLOPPY_DISK]+"/tmp");
		file.getParentFile().mkdirs();
		file = new File (Game.generatedCodeDirName+"RAM data/"+BuildDisk.MODE_LABEL[BuildDisk.MEGAROM_T2]+"/tmp");
		file.getParentFile().mkdirs();		
		
		final File downloadDirectory = new File(Game.generatedCodeDirName+"RAM data/"+BuildDisk.MODE_LABEL[BuildDisk.FLOPPY_DISK]);   
	    final File[] files = downloadDirectory.listFiles( (dir,name) -> name.matches(".*\\.raw" ));
	    Arrays.asList(files).stream().forEach(File::delete);
	    final File[] filesExo = downloadDirectory.listFiles( (dir,name) -> name.matches(".*\\.exo" ));
	    Arrays.asList(filesExo).stream().forEach(File::delete);	
	    
		final File downloadDirectoryT2 = new File(Game.generatedCodeDirName+"RAM data/"+BuildDisk.MODE_LABEL[BuildDisk.MEGAROM_T2]);   
	    final File[] filesT2 = downloadDirectoryT2.listFiles( (dir,name) -> name.matches(".*\\.raw" ));
	    Arrays.asList(filesT2).stream().forEach(File::delete);
	    final File[] filesT2Exo = downloadDirectoryT2.listFiles( (dir,name) -> name.matches(".*\\.exo" ));
	    Arrays.asList(filesT2Exo).stream().forEach(File::delete);		    
	}

}
