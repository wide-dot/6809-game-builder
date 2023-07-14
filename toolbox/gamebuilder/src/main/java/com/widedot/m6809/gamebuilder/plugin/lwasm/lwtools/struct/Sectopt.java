package com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.struct;

public class Sectopt {
	public String name;			// section name
	public int aftersize;		// number of bytes to append to section
	public String afterbytes;	// the bytes to store after the section
	public Sectopt next;		// next section option
}
