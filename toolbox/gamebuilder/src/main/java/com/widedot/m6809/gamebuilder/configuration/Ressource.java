package com.widedot.m6809.gamebuilder.configuration;

import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.HashMap;

import com.widedot.m6809.gamebuilder.lwtools.LwAssembler;
import com.widedot.m6809.gamebuilder.lwtools.format.LwObject;
import com.widedot.m6809.gamebuilder.lwtools.format.LwRaw;
import com.widedot.m6809.gamebuilder.lwtools.struct.LWSection;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Ressource {
	public static final String BIN = "bin";
	public static final String ASM = "asm";
	
	public static int BIN_INT = 0;
	public static int ASM_INT = 1;
	
	private static final HashMap<String, Integer> id = new HashMap<String, Integer>() {
		private static final long serialVersionUID = 1L;
		{
			put(BIN, BIN_INT);
			put(ASM, ASM_INT);
		}
	};
	
	public String name;
	public String filename;
	public int type;
	public String section;
	public byte[] bin;
	
	public Ressource(String name, String file, String filename) throws Exception {
		this.name = name;
		this.filename = file;
		if (!id.containsKey(filename)) {
			throw new Exception("Unknown file type: " + filename);
		}
		this.type = id.get(filename);
	}
	
	public void computeBin(String path, HashMap<String, String> defines, String format) throws Exception {
		
	    if (type == Ressource.ASM_INT) {
	    	
	    	// assembly file
	    	Object lwbinary = LwAssembler.assemble(filename, path, defines, format);

	    	if (lwbinary instanceof LwObject) {
		        // concat code sections
		        log.debug("concat code sections");
		        
		    	int length = 0;
			    for (LWSection section : ((LwObject) lwbinary).secLst) {
			    	length += section.code.length;
			    }
			    
		        bin = new byte[length];
		        int j=0;
	            for (LWSection section : ((LwObject) lwbinary).secLst) {
	                for (int i=0; i<section.code.length; i++) {
	                	bin[j++] = section.code[i];
	                }
	            }
	    	} else if (lwbinary instanceof LwRaw) {
	    		bin = ((LwRaw) lwbinary).bin;
	    	}
            
	    } else {
	    	
	    	// binary file, nothing to assemble here
	    	bin = Files.readAllBytes(Paths.get(filename));
	    }
	}

}