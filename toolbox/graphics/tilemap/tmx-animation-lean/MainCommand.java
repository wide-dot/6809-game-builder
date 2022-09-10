package com.widedot.toolbox.graphics.tilemap;

import java.awt.Rectangle;
import java.awt.image.BufferedImage;
import java.awt.image.DataBufferByte;
import java.awt.image.IndexColorModel;
import java.awt.image.Raster;
import java.io.File;
import java.io.FilenameFilter;
import java.util.HashSet;

import javax.imageio.ImageIO;

import org.mapeditor.io.TMXMapReader;

import com.widedot.m6809.gamebuilder.util.FileUtil;

// split tile images in two parts for a given animated tilemap
// -----------------------------------------------------------
//
// the output will reduce greatly image size and rendering time at runtime
// this is only usefull when using big tiles (vertical or horizontal stripes) 
//
// a directory must be provided as an argument, if no directory is given this converter will get the launch directory
// in this directory, the converter will load all .stm files (a minimum of 2) and a tileset (there must be only one .png file in the directory)
// it will produce a subdir with :
// - a new tileset (.png) containing new splited tiles (common and specific frame parts of a tile)
// - a new map for each frame (.bin) with two tile references for each position instead of one

public class LeanTileset {
	
	// default values
	private static String inputdir = "./";
	private static int inByteDepth = 4;
	private static int outByteDepth = 2;		
	private static int fileMaxSize = 16384;
	
	public static void main(String[] paramArrayOfString) throws Exception {

		// check input parameters
		if (paramArrayOfString.length != 4 && paramArrayOfString.length != 0) {
			System.err.println("Usage: leantls.bat (or .sh) <input directory> <input tile id byte size> <ouput tile id byte size> <max output file size ex: 16384>");
			System.err.println("if no parameters, default values will be used:");
			System.err.println("- process .stm files in launch directory");
			System.err.println("- 4 bytes input tile id");
			System.err.println("- 2 bytes output tile id");
			System.err.println("- split files greater than 16384 bytes");
			return;
		}
		
		if (paramArrayOfString.length != 0) {
			// get input parameters
			inputdir = paramArrayOfString[0];
			inByteDepth = Integer.parseInt(paramArrayOfString[1]);
			outByteDepth = Integer.parseInt(paramArrayOfString[2]);		
			fileMaxSize = Integer.parseInt(paramArrayOfString[3]);
		}

		new LeanTileset(inputdir, inByteDepth, outByteDepth, fileMaxSize);
	}	
	
	public LeanTileset(String inputdir, int inByteDepth, int outByteDepth, int fileMaxSize) throws Exception {
		try {
			
			// just a test to check tiled lib is available
			TMXMapReader mapReader = new TMXMapReader();
			
			// load each stm file of the directory		
			File dir = new File(inputdir);
			if (!dir.isDirectory()) {
				throw new Exception("input directory does not exists");
			}
			
			File[] files = dir.listFiles((d, name) -> name.endsWith(".stm"));
			SimpleTileMap[] stm = new SimpleTileMap[files.length];
			int i = 0;
			for (final File stmfile : files) {
				stm[i++] = new SimpleTileMap(stmfile, inByteDepth, outByteDepth);
			}  
			
			// check that all stm files have the same map size
			// TODO
		
			// load the tileset of the directory
			// it is assumed that there is only one image in the processing directory
			// tileset must be arranged with one tile per row
			// Get all images in directory
        	System.out.println("search for tileset in directory: "+inputdir);
        	File[] file= dir.listFiles(IMAGE_FILTER);
            if (file.length != 1) {
            	throw new Exception("input directory must contain only one tileset (.png file). number of .png found: "+i);
            }
            BufferedImage tls = ImageIO.read(file[0]);
            
            int tileWidth = 16;
            int tileHeight = 192;
            int nbTiles = 71;
            int tlsWidth = 1;
            int tlsHeight = 71;
            byte[][] tileImg = new byte[nbTiles][];
            Raster[] tileRaster = new Raster[nbTiles];
            
            for (int tileId = 0; tileId < nbTiles; tileId++) {
            	Rectangle bounds = new Rectangle((tileId%tlsWidth)*tileWidth, (tileId/tlsWidth)*tileHeight, tileWidth, tileHeight);
            	tileRaster[tileId] = tls.getData(bounds);
            	tileImg[tileId] = ((DataBufferByte)tileRaster[tileId].getDataBuffer()).getData();
            }
            
            // loop thru each map position in all animation frame submap
            for (int mapPos = 0; mapPos < stm[0].data.length; mapPos+=outByteDepth) {
            	System.out.print("\nposition " + mapPos + " (map:tileid) ");
            	
        		// add distinct tile id into a hashmap of tile to process
            	HashSet<Integer> tiles = new HashSet<Integer>();
            	for (int map = 0; map < stm.length; map++) {
            		int tileId = (((stm[map].data[mapPos]&0xff)<<8)+stm[map].data[mapPos+1]);
            		System.out.print(map + ":" + tileId + " ");
            		if (!tiles.contains(tileId)) {
            			tiles.add(tileId);
            		}
            	}
            	
            	// init common image
		        BufferedImage commonImg = new BufferedImage(tileWidth, tileHeight, BufferedImage.TYPE_BYTE_INDEXED, (IndexColorModel) tls.getColorModel());
        	    byte[] commonImgData = ((DataBufferByte)commonImg.getRaster().getDataBuffer()).getData();            	
        	    int nbPixels = tileWidth*tileHeight;
           	
            	if(tiles.size()>1) {

            		// parse all pixels one by one in all tiles
            		boolean diff;
            		for (int px = 0; px < nbPixels; px++) {
            			diff = false;
            			byte value = (byte) 0xff;
            			for (Integer tileId : tiles) {
            				if (value != (byte) 0xff && value != tileImg[tileId][px]) {
            					diff = true;
            					break;
            				}
            				value = tileImg[tileId][px];            				
            			}
            			
            			if (!diff) {
            				commonImgData[px] = value; // copy this common pixel value to common tile image
            				for (Integer tileId : tiles) {
            					tileImg[tileId][px] = 0; // set this pixel to transparent color for all tiles
            				}
            			}
	            	}
	    		
	            	// save common tileset
            		File newTileset = new File(file[0].getPath().toString()+"common-image-"+(mapPos/2)+".png");
            		ImageIO.write(commonImg, "png", newTileset);
            		
            		// save common tilemap
            		// TODO
            		
	            	tiles.clear();
	            }
            }
            
            // save animation tileset
            for (int tileId = 0; tileId < nbTiles; tileId++) {
            	tls.setData(tileRaster[tileId]);
            }            
    		File newTileset = new File(FileUtil.removeExtension(file[0].toString())+".lean.png");
    		ImageIO.write(tls, "png", newTileset);            		


		} catch (Exception e) {
			e.printStackTrace();
			System.err.println(e);
		}	
	}
	
    static final FilenameFilter IMAGE_FILTER = new FilenameFilter() {

        @Override
        public boolean accept(final File dir, final String name) {
            for (final String ext : EXTENSIONS) {
                if (name.endsWith("." + ext)) {
                    return (true);
                }
            }
            return (false);
        }
    };	
    
    static final String[] EXTENSIONS = new String[]{
            "png"
        };    
    	
}