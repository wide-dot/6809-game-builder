package com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;

import com.widedot.m6809.gamebuilder.spi.ObjectDataType;

public class LwRaw implements ObjectDataType{

	public byte[] bin;
	
	public LwRaw(String filename) throws IOException {
		bin = Files.readAllBytes(Paths.get(filename));
	}

	@Override
	public byte[] getBytes() throws Exception {
		return bin;
	}
	
}
