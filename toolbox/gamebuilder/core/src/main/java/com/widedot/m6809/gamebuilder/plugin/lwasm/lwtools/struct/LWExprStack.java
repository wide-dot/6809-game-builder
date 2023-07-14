package com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.struct;

import java.io.Serializable;

public class LWExprStack implements Serializable{
	private static final long serialVersionUID = 1L;
	
	public LWExprStackNode head = null;
	public LWExprStackNode tail = null;
	
	public boolean lw_expr_is_constant() {
		return (head == tail && (head == null || head.term.term_type == LWExprTerm.LW_TERM_INT));
	}
}
