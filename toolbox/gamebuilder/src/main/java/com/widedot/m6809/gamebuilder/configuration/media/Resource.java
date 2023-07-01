package com.widedot.m6809.gamebuilder.configuration.media;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Resource {
	public static final String BIN = "bin";
	public static final String ASM = "asm";
	
	public static int BIN_INT = 0;
	public static int ASM_INT = 1;
	
	public static final HashMap<String, Integer> id = new HashMap<String, Integer>() {
		private static final long serialVersionUID = 1L;
		{
			put(BIN, BIN_INT);
			put(ASM, ASM_INT);
		}
	};
	
	public String filename;
	public int filetype;
	public byte[] bin;
	
	public Resource(String filename, String filetype) throws Exception {
		this.filename = filename;
		if (!id.containsKey(filetype)) {
			throw new Exception("Unknown file type: " + filetype);
		}
		this.filetype = id.get(filetype);
		
		Path path = Paths.get(filename);
		bin = Files.readAllBytes(path);
	}

}