package com.widedot.toolbox.graphics.raycast;

import java.awt.image.BufferedImage;
import java.awt.image.IndexColorModel;
import java.io.File;

import javax.imageio.ImageIO;

/**
 * The map : a grid of cells, 0 empty or a texture number. Read from an
 * indexed picture, a pixel a cell, the colour index the cell's value. Its
 * border must be walls : a ray always stops inside the grid.
 */
final class GridMap {

	final int width;
	final int height;
	final int[] cells;

	GridMap(int width, int height, int[] cells) {
		this.width = width;
		this.height = height;
		this.cells = cells;
	}

	static GridMap read(String file, int textures) throws Exception {
		BufferedImage img = ImageIO.read(new File(file));
		if (img == null) {
			throw new Exception(file + " is not a picture");
		}
		if (!(img.getColorModel() instanceof IndexColorModel)) {
			throw new Exception(file + " is not an indexed picture : a pixel is a cell, its colour index 0 (empty)"
					+ " or a texture number");
		}
		int w = img.getWidth();
		int h = img.getHeight();
		if (w < 3 || h < 3 || w > 255 || h > 255) {
			throw new Exception(file + " is " + w + "x" + h + " cells : 3 to 255 a side");
		}
		int[] cells = new int[w * h];
		for (int y = 0; y < h; y++) {
			for (int x = 0; x < w; x++) {
				int c = img.getRaster().getSample(x, y, 0);
				if (c > textures) {
					throw new Exception(file + " : cell (" + x + "," + y + ") is texture " + c + ", there are "
							+ textures);
				}
				if (c == 0 && (x == 0 || y == 0 || x == w - 1 || y == h - 1)) {
					throw new Exception(file + " : cell (" + x + "," + y + ") is empty on the map's border, a ray"
							+ " would leave the map");
				}
				cells[y * w + x] = c;
			}
		}
		return new GridMap(w, h, cells);
	}
}
