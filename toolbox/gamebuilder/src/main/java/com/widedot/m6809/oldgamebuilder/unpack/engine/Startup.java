package com.widedot.m6809.oldgamebuilder.unpack.engine;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;

import org.apache.commons.io.IOUtils;

import lombok.extern.slf4j.Slf4j;
import net.lingala.zip4j.io.inputstream.ZipInputStream;
import net.lingala.zip4j.model.LocalFileHeader;

@Slf4j
public class Startup
{
	public static String prjDir = "./";	
	public static Path prjDirPath = Path.of(prjDir).normalize().toAbsolutePath();
	
	private Startup()
	{
		// hidding constructor for this instanceless class, to prevent useless instanciation.
	}

	public static void showSplash() throws IOException
	{
		InputStream stream = Startup.class.getResourceAsStream("/splash.txt");
		IOUtils.copy(stream, System.out);		
	}

	public static boolean createProjectDirectory(String dir) throws IOException
	{
		prjDir = dir;
		if (dir == null || dir.equals("")) {
			log.info("No directory to create.");
		}
		prjDirPath = Path.of(prjDir).normalize().toAbsolutePath();
		
		if (!Files.exists(prjDirPath)) {
			Files.createDirectories(prjDirPath);
		} else {
			log.info("The directory " + prjDir + " already exists.");
			return false;
		}
		return true;
	}

	public static void extractResource(String resourceName, boolean executable) throws IOException
	{
		InputStream toolsStream = Startup.class.getResourceAsStream(resourceName);
		log.info("Extracting {} in {}", resourceName, prjDirPath);

		try (ZipInputStream zipInputStream = new ZipInputStream(toolsStream))
		{
			LocalFileHeader localFileHeader;
			while ((localFileHeader = zipInputStream.getNextEntry()) != null)
			{
				Path extractedPath = Path.of(prjDir, localFileHeader.getFileName());
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

}
