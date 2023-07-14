package com.widedot.m6809.util.math;

public class Hex {

	public static int parse(String in) {
		int val;
		if (in.contains("$")) {
			val = Integer.parseInt(in.replace("$", ""), 16);	
		} else {
			val = Integer.parseInt(in);
		}
		return val;
	}
	
}
