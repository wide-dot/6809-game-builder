package com.widedot.toolbox.graphics.gfxcomp.transformer;

import java.awt.image.BufferedImage;

/**
 * A transform in source space : pixels in, pixels out, before the image is
 * split into screen planes.
 *
 * Kept apart from {@link PlaneTransform} on purpose. The two used to share one
 * interface typed over BufferedImage, which said they were interchangeable —
 * and the pre-shift, which is not a source space operation at all, was written
 * as one for that reason. Two types make the confusion refuse to compile.
 */
public interface ImageTransform {
	BufferedImage apply(BufferedImage image);
}
