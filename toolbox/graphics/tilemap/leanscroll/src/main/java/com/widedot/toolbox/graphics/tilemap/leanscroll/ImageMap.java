package com.widedot.toolbox.graphics.tilemap.leanscroll;

import java.awt.image.BufferedImage;
import java.awt.image.DataBuffer;
import java.awt.image.DataBufferByte;
import java.awt.image.IndexColorModel;
import java.io.File;
import java.io.FileOutputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Arrays;

import javax.imageio.ImageIO;

import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class ImageMap {

	BufferedImage image;
	BufferedImage tileset;
	public int[] mapData;
	
	public ImageMap() {
	}
	
	public void BuildTileMap(BufferedImage image, int tileWidth, int tileHeight) {
		this.image = image;
		DataBuffer dataBuffer = (DataBufferByte) image.getRaster().getDataBuffer();
		
		int mapWidth = image.getWidth()/tileWidth;
		int tileSize = tileWidth*tileHeight;
		int nbTiles = dataBuffer.getSize()/tileSize;
		List<byte[]> tiles = new ArrayList<byte[]>();
		int tilesetLineWidth = tileWidth*mapWidth;
		mapData = new int[nbTiles];
		
		for (int t = 0; t < nbTiles; t++) {
			
			int tilesetPos = (t%mapWidth)*tileWidth + (t/mapWidth)*tileSize;
			byte[] tile = new byte[tileSize];
			for (int y = 0; y < tileHeight; y++) {
				for (int x = 0; x < tileWidth; x++) {
					tile[x+y*tileWidth] = (byte) dataBuffer.getElem(tilesetPos + x  + y*tilesetLineWidth);
				}
			}
			
			int index = -1;
			for (int i = 0; i < tiles.size(); i++) {
				if (Arrays.equals(tiles.get(i), tile)) {
					index = i;
				}
			}
			
			if (index == -1) {
				tiles.add(tile);
				index = tiles.size()-1;
			}
			
			mapData[t] = index;
		}
		
		// convert List<byte[]> tiles to BufferedImage
		tileset = new BufferedImage(tileWidth, tileHeight*nbTiles, BufferedImage.TYPE_BYTE_INDEXED, (IndexColorModel)image.getColorModel());
		// continue
		
	}
	
	public void WriteTileSet(File file) throws Exception {
		ImageIO.write(tileset, "png", file);
	}
	
	public void WriteMap(File file, int fileMaxSize, boolean word) throws Exception {
		int readIdx = 0;
		int writeIdx = 0;
		int fileId = 0;

		while (readIdx < mapData.length) {
			String filename = FileUtil.removeExtension(file.toString()) + "." + fileId + ".bin";
			FileOutputStream fis = new FileOutputStream(new File(filename));
			byte[] finalArray = new byte[(mapData.length-readIdx<fileMaxSize?mapData.length-readIdx:fileMaxSize)*(word?2:1)];
			writeIdx = 0;
			while (readIdx < mapData.length && writeIdx < fileMaxSize) {
				if (word) {
					finalArray[writeIdx++] = (byte) ((mapData[readIdx] >> 8) & 0xFF);
					finalArray[writeIdx++] = (byte) (mapData[readIdx++] & 0xFF);
				} else {
					finalArray[writeIdx++] = (byte) (mapData[readIdx++] & 0xFF);
				}
			}
			fis.write(finalArray);
			fis.close();
			fileId++;
		}
	}
	
}
