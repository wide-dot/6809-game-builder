package com.widedot.m6809.gamebuilder.configuration;

import java.util.HashMap;

public class Ressource {
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
	
	public String name;
	public String file;
	public int type;
	
	public Ressource(String name, String file, int type) {
		this.name = name;
		this.file = file;
		this.type = type;
	}
}
