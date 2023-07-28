package com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

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

	@Override
	public List<byte[]> getExportedConst() throws Exception {
		return new ArrayList<byte[]>();
	}

	@Override
	public List<byte[]> getExported() throws Exception {
		return new ArrayList<byte[]>();
	}

	@Override
	public List<byte[]> getLocal() throws Exception {
		return new ArrayList<byte[]>();
	}

	@Override
	public List<byte[]> getIncomplete8() throws Exception {
		return new ArrayList<byte[]>();
	}

	@Override
	public List<byte[]> getIncomplete16() throws Exception {
		return new ArrayList<byte[]>();
	}
}
