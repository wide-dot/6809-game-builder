package com.widedot.toolbox.graphics.gfxcomp.setting;

import java.util.List;

/**
 * The video mode the compiled code draws in, as the gfxcomp element names it
 * (videomode, the attribute png2bin already uses for the same notion).
 *
 * bm16 is the encoders' own model : a source pixel is a 4 bit BM16 pixel.
 * bm4s is the TO8 bitmap 4 "special" mode ($41, 320x200 in 4 colours), whose
 * byte layout is BM16's with 2 bit pixels : a source picture of 320 pixels in
 * 4 colours is packed by pixel pairs into the 160 pixel BM16 picture the
 * encoders already draw (PixelPairs), and nothing downstream changes.
 */
public final class VideoMode {

	public static final String BM16 = "bm16";
	public static final String BM4S = "bm4s";

	/** the names the videomode attribute accepts, in the order the errors list them */
	public static final List<String> NAMES = List.of(BM16, BM4S);

	private VideoMode() {
	}

	/** the known mode a name designates, in any case as png2bin reads it ; an error naming the known ones otherwise */
	// the toolchain signals build errors with plain Exceptions
	@SuppressWarnings("PMD.AvoidThrowingRawExceptionTypes")
	public static String check(String name) throws Exception {
		String mode = name.toLowerCase(java.util.Locale.ROOT);
		if (!NAMES.contains(mode)) {
			throw new Exception("<gfxcomp> videomode '" + name + "' is not one of " + NAMES);
		}
		return mode;
	}
}
