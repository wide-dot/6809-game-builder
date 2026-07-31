package com.widedot.m6809.gamebuilder.spi.configuration;

/**
 * Parsing of the value notations used in configuration files.
 */
public final class Values {

	private Values() {
	}

	/**
	 * Parses an integer in the notations the 6809 world actually uses :
	 * decimal, 0x hexadecimal, and $ hexadecimal.
	 *
	 * Replaces Integer.decode, which silently read a leading zero as octal —
	 * a "sector=010" would have meant 8.
	 *
	 * @return the value, or null when the input is null
	 * @throws NumberFormatException when the input matches no notation
	 */
	public static Integer parseInt(String s) {
		if (s == null) {
			return null;
		}
		String v = s.trim();
		boolean negative = v.startsWith("-");
		if (negative) {
			v = v.substring(1);
		}

		int value;
		if (v.startsWith("$")) {
			value = Integer.parseInt(v.substring(1), 16);
		} else if (v.startsWith("0x") || v.startsWith("0X")) {
			value = Integer.parseInt(v.substring(2), 16);
		} else {
			value = Integer.parseInt(v, 10);
		}
		return negative ? -value : value;
	}
}
