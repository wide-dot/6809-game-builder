package com.widedot.toolbox.graphics.tilemap.leanscroll;

import java.awt.image.BufferedImage;
import java.io.File;
import java.nio.file.Files;
import java.nio.file.Paths;

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

@Command(name = "leanscroll", description = "")
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
	
    @Option(names = { "-outtilewidth"}, description = "Output tile width in pixel")
    private Integer outtileWidth = null;
    
    @Option(names = { "-outtileheight"}, description = "Output tile Height in pixel")
    private Integer outtileHeight = null;
    
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

	// LEAN parameters
	// ************************************************************************
	
    @ArgGroup(exclusive = false)
    DepLean depLean;

    static class DepLean {
    	@Option(names = { "-scrollstep"}, required=true, split = ",", description = "Scroll step in pixels for each directions : U,D,L,R,UL,UR,DL,DR ex: 0,0,2,0,0,0,0,0 for left scrolling of 2 pixels")
        private int[] scrollStep;

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
    
    @Option(names = { "-outmapbitdepth"}, description = "Output Tilemap bit depth")
    private int outMapBitDepth;
    
    @Option(names = { "-outmaptranspose"}, description = "Transpose Output Tilemap")
    private boolean outMapTranspose;

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
	        	
	        	// set default tile size
	        	if (outtileWidth == null) outtileWidth=exclusiveInput.inMap.tileWidth;
	        	if (outtileHeight == null) outtileHeight=exclusiveInput.inMap.tileHeight;
	        	
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

	        // Non Shifted Image
	        // ****************************************************************
			
	        // saves full map render image
	        if (outImage != null) {
	        	File file = new File(outImage);
	        	if (!file.exists())
	        		Files.createDirectories(Paths.get(file.getAbsolutePath()));
	        	ImageIO.write(tm.image, "png", file);
	        }
	        
	        BufferedImage ImageCommon = null;
	        
	        if (depLean != null) {
	        	LeanScroll ls = new LeanScroll(new Png(tm.image), depLean.scrollStep, depLean.scrollNbSteps, depLean.multiDir, depLean.interlace);
	        	if (depLean.outLeanImage != null) {
	        		File file = new File(depLean.outLeanImage);
		        	if (!file.exists())
		        		Files.createDirectories(Paths.get(file.getAbsolutePath()));
		        	ImageIO.write(ls.lean, "png", file);      	
	        	}
	        	if (depLean.crop == null) {depLean.crop = new int[] {0, 0, ls.leanCommon.getWidth(), ls.leanCommon.getHeight()};}
	        	if (depLean.outLeanImageCommon != null) {
	        		File file = new File(depLean.outLeanImageCommon);
		        	if (!file.exists())
		        		Files.createDirectories(Paths.get(file.getAbsolutePath()));
	        		ImageIO.write(ls.leanCommon.getSubimage(depLean.crop[0], depLean.crop[1], depLean.crop[2], depLean.crop[3]), "png", file);
	        	}
	        	tm.image = ls.lean;
	        	ImageCommon = ls.leanCommon;
	        }
	        
	        // saves tileset and map
	        if (depOutTileset != null) {
		        ImageMap imgMap = new ImageMap();
		        imgMap.BuildTileMap(tm.image, outtileWidth, outtileHeight);
		        imgMap.WriteTileSet(new File(depOutTileset.outTileset));
		        if (outMapTranspose) imgMap.Transpose();
		        imgMap.WriteMap(new File(depOutTileset.outTileMap), fileMaxSize, outMapBitDepth);
	        }
	        
	        // Shifted Image
	        // ****************************************************************
	        
        	BufferedImage shiftedImage = ImageTransform.shift(tm.image, 1, 0);
        	
	        if (depLean != null) {
	        	if (depLean.outLeanImageShift != null) {
	        		File file = new File(depLean.outLeanImageShift);
		        	if (!file.exists())
		        		Files.createDirectories(Paths.get(file.getAbsolutePath()));
	        		ImageIO.write(shiftedImage, "png", file);
	        	}
	        	
	        	BufferedImage shiftedImageCommon = ImageTransform.shift(ImageCommon, 1, 0);
	        	if (depLean.crop == null) {depLean.crop = new int[] {0, 0, shiftedImageCommon.getWidth(), shiftedImageCommon.getHeight()};}
	        	if (depLean.outLeanImageCommonShift != null)  {
	        		File file = new File(depLean.outLeanImageCommonShift);
		        	if (!file.exists())
		        		Files.createDirectories(Paths.get(file.getAbsolutePath()));
		        	ImageIO.write(shiftedImageCommon.getSubimage(depLean.crop[0], depLean.crop[1], depLean.crop[2], depLean.crop[3]), "png", file);
	        	}
	        }
	        
	        // saves tileset and map
	        if (depOutTileset1 != null) {
		        ImageMap imgMap1 = new ImageMap();
		        imgMap1.BuildTileMap(shiftedImage, outtileWidth, outtileHeight);
		        imgMap1.WriteTileSet(new File(depOutTileset1.outTileset));
		        if (outMapTranspose) imgMap1.Transpose();
		        imgMap1.WriteMap(new File(depOutTileset1.outTileMap), fileMaxSize, outMapBitDepth);
	        }
	        
		} catch (Throwable e) {
			log.error("Error building input image.");
			e.printStackTrace();
		}
	}
}