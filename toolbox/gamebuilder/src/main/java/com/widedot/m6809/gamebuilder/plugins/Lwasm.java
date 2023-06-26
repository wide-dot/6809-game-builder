package com.widedot.m6809.gamebuilder.plugins;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.configuration.media.Group;
import com.widedot.m6809.gamebuilder.lwtools.LwAssembler;
import com.widedot.m6809.gamebuilder.lwtools.format.LwObject;
import com.widedot.m6809.gamebuilder.lwtools.format.LwRaw;
import com.widedot.m6809.gamebuilder.lwtools.struct.LWSection;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Lwasm {
	
	public byte[] bin;
	
	public Lwasm(HierarchicalConfiguration<ImmutableNode> node) throws IOException {
	    	
    	// assembly file
		
   		// load sub-elements
//   		resources = new ArrayList<Resource>();
//   		Group.recurse(node, path, resources);
		
//    	Object lwbinary = LwAssembler.assemble(filename, path, defines, format);
//
//    	if (lwbinary instanceof LwObject) {
//	        // concat code sections
//	        log.debug("concat code sections");
//	        
//	    	int length = 0;
//		    for (LWSection section : ((LwObject) lwbinary).secLst) {
//		    	length += section.code.length;
//		    }
//		    
//	        bin = new byte[length];
//	        int j=0;
//            for (LWSection section : ((LwObject) lwbinary).secLst) {
//                for (int i=0; i<section.code.length; i++) {
//                	bin[j++] = section.code[i];
//                }
//            }
//    	} else if (lwbinary instanceof LwRaw) {
//    		bin = ((LwRaw) lwbinary).bin;
//    	}
	}
	
}
