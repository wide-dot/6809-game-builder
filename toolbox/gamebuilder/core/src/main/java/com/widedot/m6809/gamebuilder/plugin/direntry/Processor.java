package com.widedot.m6809.gamebuilder.plugin.direntry;

public class Processor {
	// merge all binaries in one byte array
//	int length = 0;
//	for (byte[] b : binList) {
//		length += b.length;
//	}
//	
//	bin = new byte[length];
//	int outpos = 0;
//	for (byte[] b : binList) {
//		for (int i=0; i< b.length; i++) {
//			bin[outpos++] = b[i];
//		}
//	}
//	
//	binList.clear();
	
//	public static final String NO_CODEC = "none";
//	public static final String ZX0 = "zx0";
//
//	boolean compression = false;      
//	String codec = node.getString("[@codec]", defaults.getString("file.codec", NO_CODEC));
//
//	if (!codec.equals(NO_CODEC) && bin.length > 0) {
//		if (codec.equals(ZX0)) {
//			log.debug("Compress data with zx0");
//			byte[] output = null;
//			int[] delta = { 0 };
//			output = new Compressor().compress(new Optimizer().optimize(bin, 0, 32640, 4, false), bin, 0, false, false, delta);
//			if (bin.length > output.length) {
//				bin = output;
//				compression = true;
//			} else if (delta[0] > FloppyDiskDirectory.DELTA_SIZE) {
//				log.warn("Skip compression: delta ({}) is too high", delta[0]);
//			} else {
//				log.warn("Skip compression: compressed data is bigger or equal");
//			}
//			log.debug("Original size: {}, Packed size: {}, Delta: {}", bin.length, output.length, delta[0]);
//		}
//	}
}
