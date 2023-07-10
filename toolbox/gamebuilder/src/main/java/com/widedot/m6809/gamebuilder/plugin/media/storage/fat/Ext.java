package com.widedot.m6809.gamebuilder.plugin.media.storage.fat;

import java.util.HashMap;

public class Ext {
	
	private static Byte FTYPE_BASIC      = 0; // B
	private static Byte FTYPE_DATA       = 1; // D
	private static Byte FTYPE_MACHINE    = 2; // M
	private static Byte FTYPE_ASM        = 3; // A

	private static Byte DTYPE_BINARY = 0;
	private static Byte DTYPE_ASCII  = (byte) 0xFF;

	private static HashMap<String, Byte> fType = new HashMap<String, Byte>() {
		private static final long serialVersionUID = 1L;
		{
		put("BAS", FTYPE_BASIC  );
		put("DAT", FTYPE_DATA   );
		put("ASC", FTYPE_DATA   );
		put("ASM", FTYPE_ASM    );
		put("BIN", FTYPE_MACHINE);
		put("MAP", FTYPE_MACHINE);
		put("CHG", FTYPE_DATA   );
		put("CFG", FTYPE_MACHINE);
		put("BAT", FTYPE_BASIC  );
		put("CAR", FTYPE_DATA   );
		}
	};
	
	private static HashMap<String, Byte> dType = new HashMap<String, Byte>() {
		private static final long serialVersionUID = 1L;
		{
		put("BAS", DTYPE_BINARY);
		put("DAT", DTYPE_ASCII );
		put("ASC", DTYPE_ASCII );
		put("ASM", DTYPE_ASCII );
		put("BIN", DTYPE_BINARY);
		put("MAP", DTYPE_BINARY);
		put("CHG", DTYPE_ASCII );
		put("CFG", DTYPE_BINARY);
		put("BAT", DTYPE_BINARY);
		put("CAR", DTYPE_ASCII );
		}
	};
	
	public static Byte getFType(String key) {
		if (!fType.containsKey(key)) {
			return FTYPE_MACHINE;
		}
		return fType.get(key);
	}
	
	public static Byte getDType(String key) {
		if (!dType.containsKey(key)) {
			return DTYPE_BINARY;
		}
		return dType.get(key);
	}

}
