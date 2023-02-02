package com.widedot.toolbox.graphics.tilemap.leanscroll;

import java.awt.image.BufferedImage;
import java.awt.image.IndexColorModel;

public class ImageTransform {

	public static BufferedImage shift(BufferedImage image, int xs, int ys) {
        // shift image to produce tileset (shifted by 1px left)
        BufferedImage shiftedImage = new BufferedImage(image.getWidth(), image.getHeight(), image.getType(), (IndexColorModel)image.getColorModel());
        for (int y=0; y < image.getHeight(); y++) {
        	for (int x=0; x < image.getWidth(); x++) {
        		shiftedImage.getRaster().getDataBuffer().setElem(x+y*image.getWidth(), image.getRaster().getDataBuffer().getElem((x+xs)%image.getWidth()+((y+ys)%image.getHeight())*image.getWidth()));
        	}
        }	  
        return shiftedImage;
	}
	
}
