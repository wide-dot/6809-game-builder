package com.widedot.toolbox.debug.types;

import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;

import javax.imageio.ImageIO;

import com.widedot.toolbox.debug.ui.TextureLoader;

public class PaletteBufferImage {

	private static int[] paletteRGB;
	//private static int ThomsonRGB[] = {0,  97, 122, 143, 158, 171, 184, 194, 204, 212, 219, 227, 235, 242, 250, 255};
	private static int ThomsonRGB[] = {0,  17, 34, 51, 67, 85, 102, 119, 136, 153, 170, 187, 204, 221, 238, 255};
	private static int xres;
	private static int yres;
	private int scale;
	private static int[] pixels;
	
	public static TextureLoader image;
	
	static {
		paletteRGB = new int[4096];
		int i = 0;
		for (int r=0; r<16; r++) {
			for (int g=0; g<16; g++) {
				for (int b=0; b<16; b++) {
					paletteRGB[i] = (0xFF000000 & (255 << 24)) | (0x00FF0000 & (ThomsonRGB[r] << 16)) | (0x0000FF00 & (ThomsonRGB[g] << 8)) | (0x000000FF & ThomsonRGB[b]);
					i++;
				}
			}
		}
	}
	
	public PaletteBufferImage(int size) {
		xres = size;
		yres = size;
		image = new TextureLoader();
	}

	public int get(int scale) {
		this.scale = scale;
		pixels = new int[xres*scale*yres*scale];
		
    	for (int y = 0; y < yres; y++) {
    		for (int sy = 0; sy < scale; sy++) {
    			for (int x = 0; x < xres; x++) {
    				for (int sx = 0; sx < scale; sx++) {
    					pixels[(x*scale+sx)+(y*scale+sy)*xres*scale] = paletteRGB[x+y*xres];
    				}
    			}
	    	}
	    }
	    return image.loadTexture(pixels, xres*scale, yres*scale);
	}
	
	public int getWidth() {
		return xres*scale;
	}
	
	public int getHeight() {
		return yres*scale;
	}
	
    public void saveAsPNG(String filePath) throws IOException {
        // Create a BufferedImage from the pixel array
        BufferedImage bufferedImage = new BufferedImage(xres * scale, yres * scale, BufferedImage.TYPE_INT_ARGB);
        bufferedImage.setRGB(0, 0, xres * scale, yres * scale, pixels, 0, xres * scale);

        // Save the image as a PNG file
        File outputFile = new File(filePath);
        ImageIO.write(bufferedImage, "PNG", outputFile);
    }
}
