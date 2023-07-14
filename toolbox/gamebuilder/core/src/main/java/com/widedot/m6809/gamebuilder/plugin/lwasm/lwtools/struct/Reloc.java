package com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.struct;

import java.io.Serializable;

public class Reloc implements Serializable{
	private static final long serialVersionUID = 1L;
	
	public int offset;			// where in the section
	public int flags;			// flags for the relocation
	public LWExprStack expr;	// the expression to calculate it
	public Reloc next;			// ptr to next relocation
	
	public static int RELOC_NORM = 0;	// all default (16 bit)
	public static int RELOC_8BIT = 1;	// only use the low 8 bits for the reloc
}
