package com.widedot.toolbox.graphics.compiler.transformer.shift;

import java.awt.geom.AffineTransform;
import java.awt.image.AffineTransformOp;
import java.awt.image.BufferedImage;

import com.widedot.toolbox.graphics.compiler.transformer.Transformer;

public class Shift implements Transformer{
	
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
