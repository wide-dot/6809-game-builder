package com.widedot.m6809.gamebuilder.lwtools.struct;

public class LWExprStack {
	public LWExprStackNode head = null;
	public LWExprStackNode tail = null;
	
	public boolean lw_expr_is_constant() {
		return (head == tail && (head == null || head.term.term_type == LWExprTerm.LW_TERM_INT));
	}
}
