package com.widedot.toolbox.graphics.compiler.transformer.mirror;

import java.awt.image.BufferedImage;
import java.util.HashMap;

import com.widedot.toolbox.graphics.compiler.transformer.Transformer;

public class Mirror {

	// mirror types
	public static final String NONE = "none";
	public static final String X    = "x";
	public static final String Y    = "y";	
	public static final String XY   = "xy";
	
	public static final int NONE_INT = 0;
	public static final int X_INT    = 1;
	public static final int Y_INT    = 2;	
	public static final int XY_INT   = 3;
	
	public static final HashMap<String, Integer> id = new HashMap<String, Integer>() {
		private static final long serialVersionUID = 1L;
		{
			put(NONE, NONE_INT);
			put(X, X_INT);
			put(Y, Y_INT);
			put(XY, XY_INT);
		}
	};
	
	public static Integer getId(String key) {
		return id.get(key);
	}

	private static final Transformer[] snippets = {new MirrorNone(), new MirrorX(), new MirrorY(), new MirrorXY()};
	
	public static BufferedImage transform(BufferedImage image, Integer i) {
		return snippets[i].process(image);
	}
	
}
