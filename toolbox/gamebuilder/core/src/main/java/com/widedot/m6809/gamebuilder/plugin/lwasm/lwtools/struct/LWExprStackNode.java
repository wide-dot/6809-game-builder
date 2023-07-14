package com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.struct;

import java.io.Serializable;

public class LWExprStackNode implements Serializable{
	private static final long serialVersionUID = 1L;
	
	public LWExprTerm  term;
	public LWExprStackNode	prev;
	public LWExprStackNode	next;	
}
