package com.widedot.toolbox.graphics.tilemap.leanscroll;

import java.io.File;
import javax.imageio.ImageIO;

import lombok.extern.slf4j.Slf4j;
import picocli.CommandLine;
import picocli.CommandLine.ArgGroup;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

/**
 * lean scroll
 * - remove all repeating pixels when scrolling in some directions at some speed
 * - generate a new map and a new tileset with less pixels
 */

@Command(name = "stm2bin", description = "simple tile map to binary converter")
@Slf4j
public class MainCommand implements Runnable {
	
    @Option(names = { "-ts", "--tileset"}, paramLabel = "Tileset png image", description = "Process this png as input tileset")
    private String tileset;

    @Option(names = { "-tw", "--tileWidth"}, paramLabel = "", description = "")
    private int tileWidth;
    
    @Option(names = { "-th", "--tileheight"}, paramLabel = "", description = "")
    private int tileHeight;
    
    @Option(names = { "-tsw", "--tilesetwidth"}, paramLabel = "", description = "")
    private int tilesetWidth;
    
    @ArgGroup(exclusive = true, multiplicity = "1")
    Exclusive exclusive;

    static class Exclusive {
        @Option(names = { "-csv", "--tilemapcsv"}, paramLabel = "TileMap csv data", description = "Process this csv file as input map")
        private String mapcsv;

        @ArgGroup(exclusive = false)
        Dependent dependent;

        static class Dependent {
            @Option(names = { "-tm", "--tilemap"}, paramLabel = "TileMap data", description = "Process this file as input map")
            private String map;
        	
            @Option(names = { "-mw", "--mapwidth"}, required=true, paramLabel = "", description = "")
            private int mapWidth;
            
            @Option(names = { "-mb", "--mapbitdepth"}, required=true, paramLabel = "", description = "")
            private int mapBitDepth;
            
            @Option(names = { "-be", "--bigendian"}, required=true, paramLabel = "", description = "")
            private boolean bigEndian;
        }
    }
    
    @Option(names = { "-ots", "--outtileset"}, paramLabel = "Output tileset png image", description = "Processed output tileset png")
    private String outTileset;
    
    @Option(names = { "-otm", "--outtilemap"}, paramLabel = "Output tilemap", description = "Processed output tilemap")
    private String outTileMap;
    
	@Option(names = { "-oms", "--out-max-size" }, paramLabel = "Output file max size", description = "Output file maximum size, file will be splitted beyond this value")
	private int fileMaxSize = Integer.MAX_VALUE;

	public static void main(String[] args) {
		CommandLine cmdLine = new CommandLine(new MainCommand());
		cmdLine.execute(args);
    }
	
	@Override
	public void run()
	{
		log.info("Lean scroll");
		
		try {
	        File tilesetFile = new File(tileset);
	        TileMap tm;

	        if (exclusive.dependent != null) {
	        	File mapFile = new File(exclusive.dependent.map);
	        	tm = new TileMap();
	        	tm.read(tilesetFile, tileWidth, tileHeight, tilesetWidth, mapFile, exclusive.dependent.mapWidth, exclusive.dependent.mapBitDepth, exclusive.dependent.bigEndian);
	        } else {
	        	File mapcsvFile = new File(exclusive.mapcsv);
	        	tm = new TileMap();
	        	tm.read(tilesetFile, tileWidth, tileHeight, tilesetWidth, mapcsvFile);
	        }
			
	        ImageMap imgMap = new ImageMap();
	        imgMap.BuildTileMap(tm.image, 14, 14);
	        imgMap.WriteTileSet(new File(outTileset));
	        imgMap.WriteMap(new File(outTileMap), fileMaxSize, false);
	        
		} catch (Exception e) {
			log.error("Error building input image.");
			e.printStackTrace();
		}
	}
}