package com.widedot.toolbox.graphics.tilemap.leanscroll;

import java.awt.image.BufferedImage;
import java.awt.image.ColorModel;
import java.awt.image.DataBuffer;
import java.awt.image.DataBufferByte;
import java.awt.image.IndexColorModel;
import java.io.File;

import javax.imageio.ImageIO;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Png {
	
	public BufferedImage image;
	public ColorModel colorModel;
	public int width;
	public int height;
	public DataBuffer dataBuffer;
	
	public Png(BufferedImage i) throws Exception {
		set(i);
	}
	
	public Png(File paramFile) throws Exception {
		
		log.info("Read "+paramFile.getAbsolutePath()+ " file ...");
		set(ImageIO.read(paramFile));
	}
	
	public void set(BufferedImage i) throws Exception {
		image = i;
		width = image.getWidth();
		height = image.getHeight();
		colorModel = image.getColorModel();
		dataBuffer = (DataBufferByte) image.getRaster().getDataBuffer();
		
		if (!(colorModel instanceof IndexColorModel)) {
			log.info("Unsupported file format: colors are not indexed.");
			throw new Exception ("png file format error.");
		}
	}
}