package com.widedot.toolbox.graphics.tilemap.leanscroll;

import java.awt.image.BufferedImage;
import java.nio.charset.StandardCharsets;
import java.awt.image.IndexColorModel;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.nio.charset.Charset;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.io.ByteOrderMark;
import org.apache.commons.io.input.BOMInputStream;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class TileMap {

	Png tilesetPng;
	public byte[][] tiles;	
	public int tileWidth;
	public int tileHeight;
	
	public int[] mapData;
	public int mapWidth;
	public int mapHeight;
	
	BufferedImage image;
	int imgWidth;
	int imgHeight;
	
	public TileMap() throws Exception {
	}
	
	public void read(File tileset, int tileWidth, int tileHeight, int tilesetWidth, File map, int mapWidth, int mapBitDepth, boolean bigEndian) throws Exception {
		readTileSet(tileset, tileWidth, tileHeight, tilesetWidth);
		readMap(map, mapWidth, mapBitDepth, bigEndian);
		buildImage();
	}

	public void read(File tileset, int tileWidth, int tileHeight, int tilesetWidth, File map) throws Exception {
		readTileSet(tileset, tileWidth, tileHeight, tilesetWidth);
		readMapCSV(map);
		buildImage();
	}
	
	private void readTileSet(File file, int tileWidth, int tileHeight, int tilesetWidth) throws Exception {		
		
		this.tileWidth = tileWidth;
		this.tileHeight = tileHeight;
		tilesetPng = new Png();
		tilesetPng.read(file);
		
		// read png and extract each tile
		int tileSize = tileWidth*tileHeight;
		int nbTiles = tilesetPng.dataBuffer.getSize()/tileSize;
		tiles = new byte[nbTiles][tileSize];
		
		int tilesetLineWidth = tileWidth*tilesetWidth;
		
		for (int t = 0; t < nbTiles; t++) {
			
			int tilesetPos = (t%tilesetWidth)*tileWidth + (t/tilesetWidth)*tileSize;
			
			for (int y = 0; y < tileHeight; y++) {
				for (int x = 0; x < tileWidth; x++) {
					tiles[t][x+y*tileWidth] = (byte) tilesetPng.dataBuffer.getElem(tilesetPos + x  + y*tilesetLineWidth);
				}
			}
		}
	}
	
	private void readMap(File map, int mapWidth, int mapBitDepth, boolean bigEndian) throws IOException {
		
		// read map data
		byte[] raw = Files.readAllBytes(map.toPath());
		int bytes = (mapBitDepth/8);
		mapData = new int[raw.length/bytes];
		this.mapWidth = mapWidth;
		this.mapHeight = mapData.length/mapWidth;
		int k = 0;
		
		if (bigEndian) {
			for (int i = 0; i < raw.length; i += bytes) {
				for (int j = 0; j < bytes; j++) {
					mapData[k] = (mapData[k] << 8) | (raw[i+j] & 0xFF);
				}
				k++;
			}
		} else {
			for (int i = 0; i < raw.length; i += bytes) {
				for (int j = bytes; j > 0; j--) {
					mapData[k] = (mapData[k] << 8) | (raw[i+j] & 0xFF);
				}
				k++;
			}
		}
	}
	
	private void readMapCSV(File map) throws Exception {
		
        try(InputStream inputStream = new FileInputStream(map)){
            BOMInputStream bomInputStream = new BOMInputStream(inputStream ,ByteOrderMark.UTF_8, ByteOrderMark.UTF_16LE, ByteOrderMark.UTF_16BE, ByteOrderMark.UTF_32LE, ByteOrderMark.UTF_32BE);
            Charset charset;
            if(!bomInputStream.hasBOM()) charset = StandardCharsets.UTF_8;
            else if(bomInputStream.hasBOM(ByteOrderMark.UTF_8)) charset = StandardCharsets.UTF_8;
            else if(bomInputStream.hasBOM(ByteOrderMark.UTF_16LE)) charset = StandardCharsets.UTF_16LE;
            else if(bomInputStream.hasBOM(ByteOrderMark.UTF_16BE)) charset = StandardCharsets.UTF_16BE;
            else { throw new Exception("The charset of the file " + map.getAbsolutePath() + " is not supported.");}
            
    		// read map data
    		try (Reader streamReader = new InputStreamReader(bomInputStream, charset)) {
    			BufferedReader br = new BufferedReader(streamReader);
    			int i = 0;
    			String line;
    			boolean firstLine = true;
    		    List<Integer> records = new ArrayList<>();
    		    while ((line = br.readLine()) != null) {
    		    	for (String s : line.split(";")) {
    		    		records.add(Integer.valueOf(s));
    		    	}
    		    	if (firstLine) {
    		    		mapWidth = records.size();
    		    		firstLine = false;
    		    	}
    		    }
    		    
    		    mapData = new int[records.size()];
    		    for (Integer record : records) {
    		    	mapData[i++] = record;
    		    }
    		    
    			mapHeight = mapData.length/mapWidth;
    		}
        }
		
	}
	
	private void buildImage() {
		imgWidth = mapWidth*tileWidth;
		imgHeight = mapHeight*tileHeight;
		int tileSize = tileWidth*tileHeight;
		image = new BufferedImage(imgWidth, imgHeight, BufferedImage.TYPE_BYTE_INDEXED, (IndexColorModel)tilesetPng.colorModel);
		
		for (int ty = 0; ty < mapHeight; ty++) {
			for (int tx = 0; tx < mapWidth; tx++) {
				
				int tileId = mapData[tx+ty*mapWidth];
				int mapPos = tx*tileWidth + ty*mapWidth*tileSize;
				
				for (int y = 0; y < tileHeight; y++) {
					for (int x = 0; x < tileWidth; x++) {
						image.getRaster().getDataBuffer().setElem(mapPos + x + y*imgWidth, tiles[tileId][x + y*tileWidth]);
					}
				}
			}
		}
	}
	
}
