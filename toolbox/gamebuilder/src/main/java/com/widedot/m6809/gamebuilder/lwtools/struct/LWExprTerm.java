package com.widedot.m6809.gamebuilder.lwtools.struct;

public class LWExprTerm {
	public int term_type = 0;		// type of term (see above)
	public String symbol = null;	// name of a symbol
	public int value     = 0;		// value of the term (int) or operator number (OPER)
	
	// term types
	public static final int LW_TERM_NONE = 0;
	public static final int LW_TERM_OPER = 1;	// an operator
	public static final int LW_TERM_INT  = 2;	// 32 bit signed integer
	public static final int LW_TERM_SYM  = 3;	// symbol reference

	// operator types
	public static final int LW_OPER_NONE   = 0;
	public static final int LW_OPER_PLUS   = 1;		// +
	public static final int LW_OPER_MINUS  = 2;		// -
	public static final int LW_OPER_TIMES  = 3;		// *
	public static final int LW_OPER_DIVIDE = 4;		// /
	public static final int LW_OPER_MOD    = 5;		// %
	public static final int LW_OPER_INTDIV = 6;		// \ (don't end line with \)
	public static final int LW_OPER_BWAND  = 7;		// bitwise AND
	public static final int LW_OPER_BWOR   = 8;		// bitwise OR
	public static final int LW_OPER_BWXOR  = 9;		// bitwise XOR
	public static final int LW_OPER_AND    = 10;	// boolean AND
	public static final int LW_OPER_OR     = 11;	// boolean OR
	public static final int LW_OPER_NEG    = 12;	// - unary negation (2's complement)
	public static final int LW_OPER_COM    = 13;	// ^ unary 1's complement

	public LWExprTerm(String symb, int val) {
		symbol = symb;
		value = val;
		term_type = LW_TERM_SYM;
	}	
	
	public LWExprTerm(int val, int type) {
		value = val;
		term_type = type;
	}
	
	public LWExprTerm(String symb, int val, int type) {
		symbol = symb;
		value = val;
		term_type = type;
	}	
	
}
