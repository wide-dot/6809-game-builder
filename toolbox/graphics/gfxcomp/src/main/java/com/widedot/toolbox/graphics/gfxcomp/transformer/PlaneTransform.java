package com.widedot.toolbox.graphics.gfxcomp.transformer;

/**
 * A transform in screen space : it rewrites the interlaced planes an image has
 * been split into, and never the source pixels.
 *
 * Anything reached through this interface runs *after* the geometry has been
 * measured, so a variant produced by one of these declares the same bounding
 * box as the variant it derives from. The imageset depends on that: it stores
 * a single x1/y1 per mirror group, shared by every variant in it.
 */
public interface PlaneTransform {

	/**
	 * @param pixels colour index per plane, 80 bytes per line
	 * @param data   the same planes with the drawing value (index - 1)
	 * @param height lines
	 */
	void apply(byte[][] pixels, byte[][] data, int height);
}
