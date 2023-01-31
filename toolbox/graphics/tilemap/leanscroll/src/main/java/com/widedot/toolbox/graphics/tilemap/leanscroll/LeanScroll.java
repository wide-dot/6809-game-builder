package com.widedot.toolbox.graphics.tilemap.leanscroll;

import java.awt.image.BufferedImage;

import java.awt.image.ColorModel;
import java.awt.image.IndexColorModel;
import java.awt.image.WritableRaster;
import java.io.File;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class LeanScroll{
	
	Png png;
	public Integer interlace; 	
	private  boolean multiDir;
	public int[] scrollSteps;
	public int[] scrollNbSteps;
	private static int U=0, D=1, L=2, R=3, UL=4, UR=5, DL=6, DR=7;
	
	public BufferedImage lean;
	public BufferedImage leanCommon;
	public int width;
	public int height;
	
	public LeanScroll(Png png, int[] scrollSteps, int[] scrollNbSteps, boolean multiDir, Integer interlace) throws Throwable {

		this.png = png;
		width = png.getWidth();
		height = png.getHeight();
		this.scrollSteps = scrollSteps;
		this.scrollNbSteps = scrollNbSteps;

		// apply interlace by adding black lines
		if (interlace != null) {
			for (int y = 1-interlace; y < height; y+=2) {
				for (int x = 0; x < width; x++) {	
					png.getDataBuffer().setElem(x+y*width, 0);
				}
			}
		}

		// get working images
		lean = new BufferedImage(width, height, BufferedImage.TYPE_BYTE_INDEXED, (IndexColorModel)png.getColorModel());
		leanCommon = deepCopy(png.getImage());
		
		// check parameters
		if (multiDir && (scrollSteps[R] == 0 || scrollSteps[L] == 0 || scrollSteps[U] == 0 || scrollSteps[D] == 0)) {
			log.error("free scroll needs 4 directions declared (up, down, left, right).");
			return;
		}
		
		// lean images
		for (int y = 0; y < height; y++) {
			for (int x = 0; x < width; x++) {
				lean(x, y);
			}
		}
		
		// group pixels by pair in x axis
		for (int y = 0; y < height; y++) {
			for (int x = 0; x < width; x+=2) {
				group2x(x, y);
			}
		}				
	}
	
	public BufferedImage deepCopy(BufferedImage bi) {
		 ColorModel cm = bi.getColorModel();
		 boolean isAlphaPremultiplied = cm.isAlphaPremultiplied();
		 WritableRaster raster = bi.copyData(null);
		 return new BufferedImage(cm, raster, isAlphaPremultiplied, null);
	}	

	public void lean(int x, int y) {
		// upright scroll			
		if (scrollSteps[UR] != 0) {
			for (int i = scrollSteps[UR]; i <= scrollSteps[UR]*scrollNbSteps[UR]; i += scrollSteps[UR]) {							
				if (!(x+i < width && y-i >= 0 && png.getDataBuffer().getElem(x+i+(y-i)*width) == png.getDataBuffer().getElem(x+y*width))) {
					keepPixel(x,y);
					return;
				}
			}
		}
		
		// upleft scroll
		if (scrollSteps[UL] != 0) {
			for (int i = scrollSteps[UL]; i <= scrollSteps[UL]*scrollNbSteps[UL]; i += scrollSteps[UL]) {							
				if (!(x-i >= 0  && y-i >= 0 && png.getDataBuffer().getElem(x-i+(y-i)*width) == png.getDataBuffer().getElem(x+y*width))) {
					keepPixel(x,y);
					return;
				}
			}
		}
		
		// downright scroll			
		if (scrollSteps[DR] != 0) {
			for (int i = scrollSteps[DR]; i <= scrollSteps[DR]*scrollNbSteps[DR]; i += scrollSteps[DR]) {							
				if (!(x+i < width && y+i < height && png.getDataBuffer().getElem(x+i+(y+i)*width) == png.getDataBuffer().getElem(x+y*width))) {
					keepPixel(x,y);
					return;
				}
			}
		}
		
		// downleft scroll
		if (scrollSteps[DL] != 0) {
			for (int i = scrollSteps[DL]; i <= scrollSteps[DL]*scrollNbSteps[DL]; i += scrollSteps[DL]) {							
				if (!(x-i >= 0  && y+i < height && png.getDataBuffer().getElem(x-i+(y+i)*width) == png.getDataBuffer().getElem(x+y*width))) {
					keepPixel(x,y);
					return;
				}
			}
		}			
		
		// Right scroll			
		if (scrollSteps[R] != 0) {
			for (int i = scrollSteps[R]; i <= scrollSteps[R]*scrollNbSteps[R]; i += scrollSteps[R]) {							
				if (!(x+i < width && png.getDataBuffer().getElem(x+i+y*width) == png.getDataBuffer().getElem(x+y*width))) {
					keepPixel(x,y);
					return;
				}
			}
		}
		
		// Left scroll
		if (scrollSteps[L] != 0) {
			for (int i = scrollSteps[L]; i <= scrollSteps[L]*scrollNbSteps[L]; i += scrollSteps[L]) {							
				if (!(x-i >= 0 && png.getDataBuffer().getElem(x-i+y*width) == png.getDataBuffer().getElem(x+y*width))) {
					keepPixel(x,y);
					return;
				}
			}
		}
		
		// Down scroll			
		if (scrollSteps[D] != 0) {
			for (int i = scrollSteps[D]; i <= scrollSteps[D]*scrollNbSteps[D]; i += scrollSteps[D]) {							
				if (!(y+i < height && png.getDataBuffer().getElem(x+(y+i)*width) == png.getDataBuffer().getElem(x+y*width))) {
					keepPixel(x,y);
					return;
				}
			}
		}
		
		// Up scroll
		if (scrollSteps[U] != 0) {
			for (int i = scrollSteps[U]; i <= scrollSteps[U]*scrollNbSteps[U]; i += scrollSteps[U]) {							
				if (!(y-i >= 0 && png.getDataBuffer().getElem(x+(y-i)*width) == png.getDataBuffer().getElem(x+y*width))) {
					keepPixel(x,y);
					return;
				}
			}
		}			

		// free scroll			
		if (multiDir) {
			for (int i = scrollSteps[R]; i <= scrollSteps[R]*scrollNbSteps[R]; i += scrollSteps[R]) {							
				for (int j = scrollSteps[U]; j <= scrollSteps[U]*scrollNbSteps[U]; j += scrollSteps[U]) {				
					if ((x+i < width && y-j >= 0 && png.getDataBuffer().getElem(x+i+(y-j)*width) != png.getDataBuffer().getElem(x+y*width))) {
						keepPixel(x,y);
						return;
					}
				}
			}

			for (int i = scrollSteps[L]; i <= scrollSteps[L]*scrollNbSteps[L]; i += scrollSteps[L]) {	
				for (int j = scrollSteps[U]; j <= scrollSteps[U]*scrollNbSteps[U]; j += scrollSteps[U]) {
					if ((x-i >= 0  && y-j >= 0 && png.getDataBuffer().getElem(x-i+(y-j)*width) != png.getDataBuffer().getElem(x+y*width))) {
						keepPixel(x,y);
						return;
					}
				}
			}

			for (int i = scrollSteps[R]; i <= scrollSteps[R]*scrollNbSteps[R]; i += scrollSteps[R]) {
				for (int j = scrollSteps[D]; j <= scrollSteps[D]*scrollNbSteps[D]; j += scrollSteps[D]) {
					if ((x+i < width && y+j < height && png.getDataBuffer().getElem(x+i+(y+j)*width) != png.getDataBuffer().getElem(x+y*width))) {
						keepPixel(x,y);
						return;
					}
				}
			}

			for (int i = scrollSteps[L]; i <= scrollSteps[L]*scrollNbSteps[L]; i += scrollSteps[L]) {		
				for (int j = scrollSteps[D]; j <= scrollSteps[D]*scrollNbSteps[D]; j += scrollSteps[D]) {
					if ((x-i >= 0  && y+j < height && png.getDataBuffer().getElem(x-i+(y+j)*width) != png.getDataBuffer().getElem(x+y*width))) {
						keepPixel(x,y);
						return;
					}
				}
			}
		}
	}	
	
	public void keepPixel(int x, int y) {
		lean.getRaster().getDataBuffer().setElem(x+y*width, png.getDataBuffer().getElem(x+y*width));
		leanCommon.getRaster().getDataBuffer().setElem(x+y*width, 0);
	}
	
	public void group2x(int x, int y) {
		if ((lean.getRaster().getDataBuffer()).getElem(x+(y*width)) == 0 && (lean.getRaster().getDataBuffer()).getElem(x+1+(y*width)) != 0){
			keepPixel(x,y);
			return;
		}
		
		if ((lean.getRaster().getDataBuffer()).getElem(x+(y*width)) != 0 && (lean.getRaster().getDataBuffer()).getElem(x+1+(y*width)) == 0){
			keepPixel(x+1,y);
			return;
		}
	}
	
}