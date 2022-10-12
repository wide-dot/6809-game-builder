package com.widedot.toolbox.graphics.compiler.transformer.mirror;

import java.awt.image.BufferedImage;

import com.widedot.toolbox.graphics.compiler.transformer.Transformer;

public class MirrorNone implements Transformer{

	public BufferedImage process(BufferedImage image, Integer...integers) {
		return image;
	}

}
