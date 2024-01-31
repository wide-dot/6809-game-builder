package com.widedot.toolbox.graphics.gfxcomp.transformer.mirror;

import java.awt.geom.AffineTransform;
import java.awt.image.AffineTransformOp;
import java.awt.image.BufferedImage;

import com.widedot.toolbox.graphics.gfxcomp.transformer.Transformer;

public class MirrorY implements Transformer{

	public BufferedImage process(BufferedImage image, Integer...integers) {
		AffineTransform tx = AffineTransform.getScaleInstance(1, -1);
		tx.translate(0, -image.getHeight(null));
		AffineTransformOp op = new AffineTransformOp(tx, AffineTransformOp.TYPE_NEAREST_NEIGHBOR);
		return op.filter(image, null);
	}
	
}
