package com.widedot.toolbox.graphics.gfxcomp.transformer.mirror;

import java.awt.image.BufferedImage;

import com.widedot.toolbox.graphics.gfxcomp.transformer.ImageTransform;

public class MirrorNone implements ImageTransform{

	@Override
	public BufferedImage apply(BufferedImage image) {
		return image;
	}

}
