package com.widedot.toolbox.graphics.tilemap.leanscroll;

import java.awt.geom.AffineTransform;
import java.awt.image.AffineTransformOp;
import java.awt.image.BufferedImage;
import java.awt.image.IndexColorModel;
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
	
	// Input parameters
	// ************************************************************************
	
    @ArgGroup(exclusive = true, multiplicity = "1")
    ExclusiveInput exclusiveInput;
	
    static class ExclusiveInput {
    	
    	// Input image parameters
    	// ************************************************************************
    	
	    @Option(names = { "-image"}, description = "Input png image")
	    private String inImage;
    	
		// Input tileset parameters
		// ************************************************************************
	    
        @ArgGroup(exclusive = false)
        DependentInput inMap;

        static class DependentInput {
		    @Option(names = { "-tileset"}, required=true, description = "Input png tileset")
		    private String tileset;
		
		    @Option(names = { "-tilewidth"}, required=true, description = "Tile width in pixel")
		    private int tileWidth;
		    
		    @Option(names = { "-tileheight"}, required=true, description = "Tile Height in pixel")
		    private int tileHeight;
		    
		    @Option(names = { "-tilesetwidth"}, required=true, description = "Tileset width in pixel")
		    private int tilesetWidth;
		    
		    @ArgGroup(exclusive = true, multiplicity = "1")
		    Exclusive mapFormat;
		
		    static class Exclusive {
		    	
				// Input csv tilemap parameters
				// ************************************************************************
		    	
		        @Option(names = { "-csv"}, description = "Input csv tilemap")
		        private String mapcsv;
		
				// Input bin tilemap parameters
				// ************************************************************************
		        
		        @ArgGroup(exclusive = false)
		        DependentBinMap dependentBinMap;
		
		        static class DependentBinMap {
		            @Option(names = { "-tilemap"}, required=true, description = "Input binary tilemap")
		            private String map;
		        	
		            @Option(names = { "-mapwidth"}, required=true, description = "Tilemap width in tile")
		            private int mapWidth;
		            
		            @Option(names = { "-mapbitdepth"}, required=true, description = "Tilemap bit depth")
		            private int mapBitDepth;
		            
		            @Option(names = { "-bigendian"}, description = "Tilemap encoding in Big Endian")
		            private boolean bigEndian;
		        }
		    }
	    }
    }
    
	// Output tileset and tilemap parameters
	// ************************************************************************
    
	@Option(names = { "-outmaxsize" }, description = "Output file maximum size, file will be splitted beyond this value")
	private int fileMaxSize = Integer.MAX_VALUE;
	
    @Option(names = { "-outtilewidth"}, required=true, description = "Output tile width in pixel")
    private int outtileWidth;
    
    @Option(names = { "-outtileheight"}, required=true, description = "Output tile Height in pixel")
    private int outtileHeight;
    
    @ArgGroup(exclusive = false)
    DepOutTileset depOutTileset;

    static class DepOutTileset {
	    @Option(names = { "-outtileset"}, required=true, description = "Processed output tileset png")
	    private String outTileset;
	    
	    @Option(names = { "-outtilemap"}, required=true, description = "Processed output tilemap")
	    private String outTileMap;
    }
    
    @Option(names = { "-outimage"}, description = "Processed output image")
    private String outImage;
    
	// Output shifted tileset and tilemap parameters
	// ************************************************************************
    
    @ArgGroup(exclusive = false)
    DepOutTileset1 depOutTileset1;

    static class DepOutTileset1 {
	    @Option(names = { "-outtileset1"}, required=true, description = "Processed output tileset png (1px shift)")
	    private String outTileset;
	    
	    @Option(names = { "-outtilemap1"}, required=true, description = "Processed output tilemap (1px shift)")
	    private String outTileMap;
    }
    
    @Option(names = { "-outimage1"}, description = "Processed output image (1px shift)")
    private String outImage1;

	// LEAN parameters
	// ************************************************************************
	
    @ArgGroup(exclusive = false)
    DepLean depLean;

    static class DepLean {
    	@Option(names = { "-steps"}, required=true, split = ",", description = "Scroll step in pixels for each directions : U,D,L,R,UL,UR,DL,DR ex: 0,0,2,0,0,0,0,0 for left scrolling of 2 pixels")
        private int[] scrollSteps;

    	@Option(names = { "-nbsteps"}, required=true, split = ",", description = "Scroll number of steps for each directions : U,D,L,R,UL,UR,DL,DR ex: 0,0,1,0,0,0,0,0 for left scrolling of 1 step maximum")
        private int[] scrollNbSteps;

    	@Option(names = { "-multidir"}, description = "Multidirectional scroll, steps must be declared for up, down, left and right")
        private boolean multiDir = false;

    	@Option(names = { "-interlace"}, description = "Set black lines on even (0) or odd (1) lines")
        private Integer interlace = null;
    	
        @Option(names = { "-lean"}, description = "Output Lean Full image")	
    	private String outLeanImage;
        
        @Option(names = { "-leanC"}, description = "Output Lean Full Common image")
    	private String outLeanImageCommon;
        
        @Option(names = { "-leanS"}, description = "Output Lean Full Shifted image")
    	private String outLeanImageShift;
        
        @Option(names = { "-leanCS"}, description = "Output Lean Full Common Shifted image")
    	private String outLeanImageCommonShift;
        
    	@Option(names = { "-leanCsize"}, split = ",", description = "Lean Full Common image crop: x,y,width,height")
        private int[] crop;
    }

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
	    		Png png = new Png(new File(exclusiveInput.inImage));
	        	tm.image = png.getImage();
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
	        
	        // shift image to produce tileset (shifted by 1px left)
	        BufferedImage shiftedImage = new BufferedImage(tm.image.getWidth(), tm.image.getHeight(), tm.image.getType(), (IndexColorModel)tm.image.getColorModel());
	        for (int y=0; y < tm.image.getHeight(); y++) {
	        	for (int x=0; x < tm.image.getWidth(); x++) {
	        		shiftedImage.getRaster().getDataBuffer().setElem(x+y*tm.image.getWidth(), tm.image.getRaster().getDataBuffer().getElem((x+1)%tm.image.getWidth()+y*tm.image.getWidth()));
	        	}
	        }

	        // Non Shifted Image
	        // ****************************************************************
			
	        // saves full map render image
	        if (outImage != null) {
	        	ImageIO.write(tm.image, "png", new File(outImage));
	        }
	        
	        if (depLean != null) {
	        	LeanScroll ls = new LeanScroll(new Png(tm.image), depLean.scrollSteps, depLean.scrollNbSteps, depLean.multiDir, depLean.interlace);
	        	if (depLean.outLeanImage != null) ImageIO.write(ls.lean, "png", new File(depLean.outLeanImage));      	
	        	if (depLean.crop == null) {depLean.crop = new int[] {0, 0, ls.leanCommon.getWidth(), ls.leanCommon.getHeight()};}
	        	if (depLean.outLeanImageCommon != null) ImageIO.write(ls.leanCommon.getSubimage(depLean.crop[0], depLean.crop[1], depLean.crop[2], depLean.crop[3]), "png", new File(depLean.outLeanImageCommon));
	        	tm.image = ls.lean;
	        }
	        
	        // saves tileset and map
	        if (depOutTileset != null) {
		        ImageMap imgMap = new ImageMap();
		        imgMap.BuildTileMap(tm.image, outtileWidth, outtileHeight);
		        imgMap.WriteTileSet(new File(depOutTileset.outTileset));
		        imgMap.WriteMap(new File(depOutTileset.outTileMap), fileMaxSize, false);
	        }
	        
	        // Shifted Image
	        // ****************************************************************
	        
	        // saves full map render image (shifted by 1px left)
	        if (outImage1 != null) {
	        	ImageIO.write(shiftedImage, "png", new File(outImage1));
	        }
	        
	        if (depLean != null) {
	        	LeanScroll ls = new LeanScroll(new Png(shiftedImage), depLean.scrollSteps, depLean.scrollNbSteps, depLean.multiDir, depLean.interlace);
	        	if (depLean.outLeanImageShift != null) ImageIO.write(ls.lean, "png", new File(depLean.outLeanImageShift));
	        	if (depLean.crop == null) {depLean.crop = new int[] {0, 0, ls.leanCommon.getWidth(), ls.leanCommon.getHeight()};}
	        	if (depLean.outLeanImageCommonShift != null) ImageIO.write(ls.leanCommon.getSubimage(depLean.crop[0], depLean.crop[1], depLean.crop[2], depLean.crop[3]), "png", new File(depLean.outLeanImageCommonShift));
	        	shiftedImage = ls.lean;
	        }
	        
	        // saves tileset and map
	        if (depOutTileset1 != null) {
		        ImageMap imgMap1 = new ImageMap();
		        imgMap1.BuildTileMap(shiftedImage, outtileWidth, outtileHeight);
		        imgMap1.WriteTileSet(new File(depOutTileset1.outTileset));
		        imgMap1.WriteMap(new File(depOutTileset1.outTileMap), fileMaxSize, false);
	        }
	        
		} catch (Throwable e) {
			log.error("Error building input image.");
			e.printStackTrace();
		}
	}
}