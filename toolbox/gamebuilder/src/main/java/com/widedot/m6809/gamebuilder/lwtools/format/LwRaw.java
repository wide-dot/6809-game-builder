package com.widedot.m6809.gamebuilder.lwtools.format;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;

public class LwRaw {

	public byte[] bin;
	
	public LwRaw(String filename) throws IOException {
		bin = Files.readAllBytes(Paths.get(filename));
	}
	
}
