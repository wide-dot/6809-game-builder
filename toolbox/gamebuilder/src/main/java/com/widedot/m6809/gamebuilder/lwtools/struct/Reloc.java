package com.widedot.m6809.gamebuilder.lwtools.struct;

public class Reloc {
	public int offset;			// where in the section
	public int flags;			// flags for the relocation
	public LWExprStack expr;	// the expression to calculate it
	public Reloc next;			// ptr to next relocation
	
	public static int RELOC_NORM = 0;	// all default (16 bit)
	public static int RELOC_8BIT = 1;	// only use the low 8 bits for the reloc
}
