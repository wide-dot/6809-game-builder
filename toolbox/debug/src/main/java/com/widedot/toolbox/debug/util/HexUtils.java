package com.widedot.toolbox.debug.util;

public class HexUtils {
	public static byte[] hexStringToByteArray(String s) {
		
		// remove non hex values
		s = s.replaceAll("[^A-Fa-f0-9]", "");
		
		// skip last char if odd string length
	    int len = s.length();
	    if (len%2 == 1) {
	    	len--;
	    }
	    
	    // convert
	    byte[] data = new byte[len / 2];
	    for (int i = 0; i < len; i += 2) {
	        data[i / 2] = (byte) ((Character.digit(s.charAt(i), 16) << 4)
	                             + Character.digit(s.charAt(i+1), 16));
	    }
	    return data;
	}
}
