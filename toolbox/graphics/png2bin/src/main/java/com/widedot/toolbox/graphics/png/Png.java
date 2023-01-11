package com.widedot.toolbox.graphics.png;

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
	
	private BufferedImage image;
	public ColorModel colorModel;
	public int width;
	public int height;
	public DataBuffer dataBuffer;

	public Png(File paramFile) throws Exception {
		
		log.info("Load "+paramFile.toString()+ " file ...");
	
		try {
			image = ImageIO.read(paramFile);
			width = image.getWidth();
			height = image.getHeight();
			colorModel = image.getColorModel();
			dataBuffer = (DataBufferByte) image.getRaster().getDataBuffer();
			
			if (!(colorModel instanceof IndexColorModel)) {
				log.error("Unsupported file format for " + paramFile.getName() + " : colors are not indexed.");
				throw new Exception ("png file format error.");
			}

		} catch (Exception e) {
			e.printStackTrace();
			log.error(e.toString());
		}
		log.info("done.");
	}
	
}