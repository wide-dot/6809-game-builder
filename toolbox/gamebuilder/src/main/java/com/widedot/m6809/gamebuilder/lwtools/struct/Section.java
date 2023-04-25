package com.widedot.m6809.gamebuilder.lwtools.struct;

import java.io.File;
import java.util.List;

public class Section {
	public String name;				// name of the section
	public int flags;				// section flags
	public int codesize;			// size of the code
	public String code;				// pointer to the code
	public int loadaddress;			// the actual load address of the section
	public int processed;			// was the section processed yet?
		
	public List<Symbol> localsyms;		// local symbol table
	public List<Symbol> exportedsyms;	// exported symbols table
	public List<Reloc> incompletes;		// table of incomplete references
	
	public File file;				// the file we are in
	
	public int aftersize;			// add this many bytes after section on output
	public String afterbytes;		// add these bytes after section on output
	
	
	public static int SECTION_BSS = 1;
	public static int SECTION_CONST = 2;
}
