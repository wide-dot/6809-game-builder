package com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;

import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;

public class LwRaw implements ObjectDataInterface{

	public byte[] bin;
	
	public LwRaw(String filename) throws IOException {
		bin = Files.readAllBytes(Paths.get(filename));
	}

	@Override
	public byte[] getBytes() throws Exception {
		return bin;
	}
	
}
