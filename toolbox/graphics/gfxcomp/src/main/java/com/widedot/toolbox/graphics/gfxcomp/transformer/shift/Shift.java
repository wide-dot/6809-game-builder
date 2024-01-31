package com.widedot.toolbox.graphics.gfxcomp.transformer.shift;

import java.awt.geom.AffineTransform;
import java.awt.image.AffineTransformOp;
import java.awt.image.BufferedImage;

import com.widedot.toolbox.graphics.gfxcomp.transformer.Transformer;

public class Shift implements Transformer{
	
	// shift types
	public static final String PREFIX  = "shift";
	public static final String SHIFT_0 = PREFIX+"0";
	public static final String SHIFT_1 = PREFIX+"1";
	public static final String SHIFT_2 = PREFIX+"2";
	public static final String SHIFT_3 = PREFIX+"3";
	public static final String SHIFT_4 = PREFIX+"4";
	public static final String SHIFT_5 = PREFIX+"5";
	public static final String SHIFT_6 = PREFIX+"6";
	public static final String SHIFT_7 = PREFIX+"7";	
	
	private static final Shift instance = new Shift(); 

	public BufferedImage process(BufferedImage image, Integer...integers) {
		AffineTransform tx = AffineTransform.getScaleInstance(1, 1);
		tx.translate(integers[0], 0);
		AffineTransformOp op = new AffineTransformOp(tx, AffineTransformOp.TYPE_NEAREST_NEIGHBOR);
		return op.filter(image, null);
	}
	
	public static BufferedImage transform(BufferedImage image, Integer shift) {
		return instance.process(image, shift);
	}
	
}
