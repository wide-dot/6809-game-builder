package com.widedot.toolbox.debug;

import java.nio.charset.StandardCharsets;

public class DataUtil {
	
    private static final byte[] HEX_ARRAY = "0123456789ABCDEF".getBytes(StandardCharsets.US_ASCII);
    
    public static String bytesToHex(byte[] bytes) {
        byte[] hexChars = new byte[bytes.length * 2];
        for (int j = 0; j < bytes.length; j++) {
            int v = bytes[j] & 0xFF;
            hexChars[j * 2] = HEX_ARRAY[v >>> 4];
            hexChars[j * 2 + 1] = HEX_ARRAY[v & 0x0F];
        }
        return new String(hexChars, StandardCharsets.UTF_8);
    }
    
    public static String bytesToHex(byte[] bytes, int pos, int length) {
        byte[] hexChars = new byte[length * 2];
        int i = 0;
        for (int j = pos; j < pos+length; j++) {
            int v = bytes[j] & 0xFF;
            hexChars[i * 2] = HEX_ARRAY[v >>> 4];
            hexChars[i * 2 + 1] = HEX_ARRAY[v & 0x0F];
            i++;
        }
        return new String(hexChars, StandardCharsets.UTF_8);
    }
    
    public static String byteToHex(byte b) {
        byte[] hexChars = new byte[2];
        hexChars[0] = HEX_ARRAY[(b & 0xFF) >>> 4];
        hexChars[1] = HEX_ARRAY[(b & 0xFF) & 0x0F];
        return new String(hexChars, StandardCharsets.UTF_8);
    }
}
