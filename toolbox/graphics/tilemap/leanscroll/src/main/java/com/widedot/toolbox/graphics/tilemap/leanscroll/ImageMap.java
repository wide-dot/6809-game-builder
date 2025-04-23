package com.widedot.toolbox.graphics.tilemap.leanscroll;

import java.awt.image.BufferedImage;
import java.awt.image.DataBuffer;
import java.awt.image.DataBufferByte;
import java.awt.image.IndexColorModel;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.OptionalInt;
import java.util.stream.IntStream;
import java.util.Arrays;

import javax.imageio.ImageIO;

import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class ImageMap {

	BufferedImage image;
	BufferedImage tileset;
	public int[] mapData;
	private int tileWidth;
	private int tileHeight;
	
	public ImageMap() {
	}
	
	public void BuildTileMap(BufferedImage image, int tileWidth, int tileHeight) {
		this.image = image;
		DataBuffer dataBuffer = (DataBufferByte) image.getRaster().getDataBuffer();
		
		this.tileWidth = tileWidth;
		this.tileHeight = tileHeight;
		int mapWidth = image.getWidth()/tileWidth;
		int tileSize = tileWidth*tileHeight;
		int nbTiles = dataBuffer.getSize()/tileSize;
		List<byte[]> tiles = new ArrayList<byte[]>();
		int tilesetLineWidth = tileWidth*mapWidth;
		mapData = new int[nbTiles];
		
		// init tile 0 to a blank tile
		tiles.add(new byte[tileSize]);
		int tilesetPos;
		for (int t = 0; t < nbTiles; t++) {
			
			// build the tile at the image position			
			tilesetPos = (t%mapWidth)*tileWidth + (t/mapWidth)*tileSize*mapWidth;
			byte[] tile = new byte[tileSize];
			for (int y = 0; y < tileHeight; y++) {
				for (int x = 0; x < tileWidth; x++) {
					tile[x+y*tileWidth] = (byte) dataBuffer.getElem(tilesetPos + x  + y*tilesetLineWidth);
				}
			}
			
			// check if tile already exists in tileset
			int index = -1;
			for (int i = 0; i < tiles.size(); i++) {
				if (Arrays.equals(tiles.get(i), tile)) {
					index = i;
				}
			}
			
			// set the map with the tile id
			if (index == -1) {
				tiles.add(tile);
				index = tiles.size()-1;
			}
			
			mapData[t] = index;
		}
		
		// convert List<byte[]> tiles to BufferedImage tileset
		tileset = new BufferedImage(tileWidth, tileHeight*tiles.size(), BufferedImage.TYPE_BYTE_INDEXED, (IndexColorModel)image.getColorModel());
		int tileOffset=0;
		int posInTile=0;
		for (byte[] tile : tiles) {
			for (int y=0; y<tileHeight; y++) {
				for (int x=0; x<tileWidth; x++) {
					posInTile = x+(y*tileWidth);
					((DataBufferByte) tileset.getRaster().getDataBuffer()).setElem(posInTile+tileOffset, tile[posInTile]);
				}
			}
			tileOffset += tileWidth*tileHeight;
		}
	}
	
	public void Transpose() {
		// transpose lines to columns
		int[] newMapData = new int[mapData.length];
		
		int mapWidth = image.getWidth()/tileWidth;
		int mapHeight = image.getHeight()/tileHeight;
		
		for (int y=0; y<mapHeight; y++) {
			for (int x=0; x<mapWidth; x++) {
				newMapData[x*mapHeight+y] = mapData[x+y*mapWidth];
			}
		}
		mapData = newMapData;
	}
	
	public void WriteTileSet(File file) throws Exception {
    	if (!file.exists())
    		Files.createDirectories(Paths.get(file.getAbsolutePath()));
		ImageIO.write(tileset, "png", file);
		String properties = (tileset.getHeight()/tileHeight)+",1,"+(tileset.getHeight()/tileHeight);
		log.info("properties for: "+file.getName()+" "+properties);
	}
	
	public void WriteMap(File file, int fileMaxSize, Integer bitDepth) throws Exception {
    	if (!file.exists())
    		Files.createDirectories(Paths.get(file.getAbsolutePath()));		
		int readIdx = 0;
		int writeIdx = 0;
		int fileId = 0;
		boolean word = (bitDepth!=null?(bitDepth==16?true:false):false);

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
