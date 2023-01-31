package com.widedot.toolbox.graphics.tilemap.leanscroll;

import java.awt.image.BufferedImage;
import java.awt.image.ColorModel;
import java.awt.image.DataBuffer;
import java.awt.image.DataBufferByte;
import java.awt.image.IndexColorModel;
import java.io.File;

import javax.imageio.ImageIO;

import lombok.Getter;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Png {
	
	@Getter
	private BufferedImage image;
	
	@Getter
	private ColorModel colorModel;
	
	@Getter
	private int width;
	
	@Getter
	private int height;
	
	@Getter
	private DataBuffer dataBuffer;
	
	public Png(BufferedImage bufferedImage) throws Exception {
		set(bufferedImage);
	}
	
	public Png(File paramFile) throws Exception {	
		log.info("Read "+paramFile.getAbsolutePath()+ " file ...");
		set(ImageIO.read(paramFile));
	}
	
	public void set(BufferedImage bufferedImage) {
		colorModel = bufferedImage.getColorModel();
		
		if (!(colorModel instanceof IndexColorModel)) {
			log.info("Unsupported file format: colors are not indexed.");
			throw new RuntimeException ("PNG file format error.");
		}
		
		this.image = bufferedImage;
		this.width = image.getWidth();
		this.height = image.getHeight();
		this.dataBuffer = (DataBufferByte) image.getRaster().getDataBuffer();		
	}
}