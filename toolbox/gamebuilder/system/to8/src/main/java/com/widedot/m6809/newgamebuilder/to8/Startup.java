package com.widedot.m6809.newgamebuilder.to8;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;

import lombok.extern.slf4j.Slf4j;

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
			log.info("Erasing temporary directory : {} ", TMP_DIR_PATH);
			FileUtils.deleteDirectory(TMP_DIR_PATH.toFile());
		}
		Files.createDirectories(TMP_DIR_PATH);
	}

	public static void clean() throws IOException {
		log.info("Clean ...");	    
	}

}
