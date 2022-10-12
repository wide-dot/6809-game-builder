package com.widedot.toolbox.graphics.compiler.transformer;

import java.awt.image.BufferedImage;

public interface Transformer {
	BufferedImage process(BufferedImage image, Integer...integers);
}
