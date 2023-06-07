package com.widedot.m6809.gamebuilder.lwtools.struct;

import java.io.Serializable;

public class Symbol implements Serializable{
	private static final long serialVersionUID = 1L;
	
	public String sym;		// symbol name
	public int offset;		// local offset
}
