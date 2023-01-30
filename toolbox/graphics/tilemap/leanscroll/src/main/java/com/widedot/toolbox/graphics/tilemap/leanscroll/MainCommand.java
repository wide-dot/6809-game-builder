package com.widedot.toolbox.graphics.tilemap.leanscroll;

import java.awt.geom.AffineTransform;
import java.awt.image.AffineTransformOp;
import java.awt.image.BufferedImage;
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
	
    @ArgGroup(exclusive = true, multiplicity = "1")
    ExclusiveInput exclusiveInput;
	
    static class ExclusiveInput {
	    @Option(names = { "-i", "--image"}, paramLabel = "Input png image", description = "Process this png as input image")
	    private String inImage;
    	
        @ArgGroup(exclusive = false)
        DependentInput inMap;

        static class DependentInput {
		    @Option(names = { "-ts", "--tileset"}, paramLabel = "Tileset png image", description = "Process this png as input tileset")
		    private String tileset;
		
		    @Option(names = { "-tw", "--tileWidth"}, paramLabel = "", description = "")
		    private int tileWidth;
		    
		    @Option(names = { "-th", "--tileheight"}, paramLabel = "", description = "")
		    private int tileHeight;
		    
		    @Option(names = { "-tsw", "--tilesetwidth"}, paramLabel = "", description = "")
		    private int tilesetWidth;
		    
		    @ArgGroup(exclusive = true, multiplicity = "1")
		    Exclusive mapFormat;
		
		    static class Exclusive {
		        @Option(names = { "-csv", "--tilemapcsv"}, paramLabel = "TileMap csv data", description = "Process this csv file as input map")
		        private String mapcsv;
		
		        @ArgGroup(exclusive = false)
		        DependentBinMap dependentBinMap;
		
		        static class DependentBinMap {
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
	    }
    }
    
    @ArgGroup(exclusive = false)
    DepOutTileset depOutTileset;

    static class DepOutTileset {
	    @Option(names = { "-ots", "--outtileset"}, paramLabel = "Output tileset png image", description = "Processed output tileset png")
	    private String outTileset;
	    
	    @Option(names = { "-otm", "--outtilemap"}, paramLabel = "Output tilemap", description = "Processed output tilemap")
	    private String outTileMap;
    }
    
    @ArgGroup(exclusive = false)
    DepOutTileset1 depOutTileset1;

    static class DepOutTileset1 {
	    @Option(names = { "-ots1", "--outtileset1"}, paramLabel = "Output tileset png image (1px shift)", description = "Processed output tileset png (1px shift)")
	    private String outTileset;
	    
	    @Option(names = { "-otm1", "--outtilemap1"}, paramLabel = "Output tilemap (1px shift)", description = "Processed output tilemap (1px shift)")
	    private String outTileMap;
    }
    
    @Option(names = { "-oi", "--outimage"}, paramLabel = "Output image", description = "Processed output image")
    private String outImage;
    
    @Option(names = { "-oi1", "--outimage1"}, paramLabel = "Output image (1px shift)", description = "Processed output image (1px shift)")
    private String outImage1;
    
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
	        TileMap tm;

	        if (exclusiveInput.inImage != null) {
		        // read input image
	        	tm = new TileMap();
	    		Png png = new Png();
	    		png.read(new File(exclusiveInput.inImage));
	        	tm.image = png.image;
	        } else {
		        // read input tilemap
		        File tilesetFile = new File(exclusiveInput.inMap.tileset);
		        if (exclusiveInput.inMap.mapFormat.dependentBinMap != null) {
		        	File mapFile = new File(exclusiveInput.inMap.mapFormat.dependentBinMap.map);
		        	tm = new TileMap();
		        	tm.read(tilesetFile, exclusiveInput.inMap.tileWidth, exclusiveInput.inMap.tileHeight, exclusiveInput.inMap.tilesetWidth, mapFile, exclusiveInput.inMap.mapFormat.dependentBinMap.mapWidth, exclusiveInput.inMap.mapFormat.dependentBinMap.mapBitDepth, exclusiveInput.inMap.mapFormat.dependentBinMap.bigEndian);
		        } else {
		        	File mapcsvFile = new File(exclusiveInput.inMap.mapFormat.mapcsv);
		        	tm = new TileMap();
		        	tm.read(tilesetFile, exclusiveInput.inMap.tileWidth, exclusiveInput.inMap.tileHeight, exclusiveInput.inMap.tilesetWidth, mapcsvFile);
		        }
	        }

			
	        // saves full map render image
	        if (outImage != null) {
	        	ImageIO.write(tm.image, "png", new File(outImage));
	        }
	        
	        // saves tileset and map
	        if (depOutTileset != null) {
		        ImageMap imgMap = new ImageMap();
		        imgMap.BuildTileMap(tm.image, 14, 14);
		        imgMap.WriteTileSet(new File(depOutTileset.outTileset));
		        imgMap.WriteMap(new File(depOutTileset.outTileMap), fileMaxSize, false);
	        }
	        

	        // shift image to produce tileset (shifted by 1px left)
	        BufferedImage image1 = new BufferedImage(tm.image.getWidth(), tm.image.getHeight(), tm.image.getType());
	        AffineTransform tx = new AffineTransform();
	        tx.translate(-1, 0);
	        AffineTransformOp op = new AffineTransformOp(tx, AffineTransformOp.TYPE_BILINEAR);
	        op.filter(tm.image, image1);
	        
	        // saves full map render image (shifted by 1px left)
	        if (outImage1 != null) {
	        	ImageIO.write(image1, "png", new File(outImage1));
	        }
	        
	        // saves tileset and map
	        if (depOutTileset1 != null) {
		        ImageMap imgMap1 = new ImageMap();
		        imgMap1.BuildTileMap(image1, 14, 14);
		        imgMap1.WriteTileSet(new File(depOutTileset1.outTileset));
		        imgMap1.WriteMap(new File(depOutTileset1.outTileMap), fileMaxSize, false);
	        }
	        
		} catch (Exception e) {
			log.error("Error building input image.");
			e.printStackTrace();
		}
	}
}