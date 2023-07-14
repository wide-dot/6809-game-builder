package com.widedot.m6809.util.graphics.encoder;

import java.awt.image.AffineTransformOp;
import java.awt.image.BufferedImage;
import java.awt.image.DataBufferByte;
import java.awt.image.IndexColorModel;
import java.awt.image.ColorModel;
import java.awt.geom.AffineTransform;
import java.io.File;
import java.nio.file.Paths;
import java.util.HashMap;

import javax.imageio.ImageIO;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import com.widedot.m6809.util.FileUtil;
import com.widedot.m6809.util.graphics.Sprite;

public class FrameDiffAutoPal {
	
	String generatedCodeDirNameDebug="";
	
	// Convertion d'une planche de sprites en tableaux de données RAMA et RAMB pour chaque Sprite
	// Thomson TO8/TO9+
	// Mode 160x200 en seize couleurs sans contraintes
	
	private static final Logger logger = LogManager.getLogger("log");	
	
	private BufferedImage image;
	private String name;
	public String variant;
	ColorModel colorModel;
	private int width; // largeur totale de l'image
	private int height; // longueur totale de l'image
	private int nbColumns; // nombre de colonnes de tiles dans l'image
	private int nbRows; // nombre de lignes de tiles dans l'image
	
	private boolean plane0_empty;
	private boolean plane1_empty;	

	private Boolean hFlipped = false; // L'image est-elle inversée horizontalement ?
	private Boolean vFlipped = false; // L'image est-elle inversée verticalement ?
	private int subImageNb; // Nombre de sous-images
	private int subImageWidth; // Largeur des sous-images
	private int subImageHeight; // HAuteur des sous-images

	private byte[][][] pixels;
	private byte[][][] data;
	int[] x1_offset; // position haut gauche de l'image par rapport au centre
	int[] y1_offset; // position haut gauche de l'image par rapport au centre		
	int[] x_size; // largeur de l'image en pixel (sans les pixels transparents)		
	int[] y_size; // hauteur de l'image en pixel (sans les pixels transparents)		
	boolean[] alpha; // vrai si l'image contient au moins un pixel transparent	
	boolean[] evenAlpha; // vrai si l'image contient au moins un pixel transparent sur les lignes paires
	boolean[] oddAlpha; // vrai si l'image contient au moins un pixel transparent sur les lignes impaires	
	public int center; // position du centre de l'image (dans le référentiel pixels)
	public int center_offset; // est ce que le centre est pair (0) ou impair (1)
	
	public static final int CENTER = 0;
	public static final int TOP_LEFT = 1;
	public static final int TILE8x16 = 2;	
	public static final HashMap<String, Integer> colorModes= new HashMap<String, Integer>(){
		private static final long serialVersionUID = 1L;
	{
			put("CENTER",CENTER);
			put("TOP_LEFT",TOP_LEFT);
			put("TILE8x16",TILE8x16);
			}};

	// TODO mutualiser les deux constructeurs
	public FrameDiffAutoPal(Sprite sprite, String associatedIdx, BufferedImage imgCumulative, int nbTiles, int nbColumns, int nbRows, String variant, boolean interlaced, int centerMode, String... fileRef) {
		try {
			this.variant = variant;
			subImageNb = nbTiles;
			image = ImageIO.read(new File(sprite.spriteFile));
			name = sprite.name;
			width = image.getWidth();
			height = image.getHeight();
			colorModel = image.getColorModel();
			int pixelSize = colorModel.getPixelSize();
			
			this.nbColumns = 1;
			this.nbRows = 1;
			
			plane0_empty = true;
			plane1_empty = true;
			
			// if more than one file is present, build an image by diff btw the two images.
			if ((sprite.associatedIdx != null && sprite.associatedIdx.startsWith("_autopal")) && fileRef.length > 0 && fileRef[0] != null) {

				// _autopal is used to swap palette color and help compression,
				// and all images should be declared in the playing order in properties file
				// currently only 4 colors are allowed, TODO allow more colors
				
				BufferedImage imgref;
				if (fileRef[0].equals("_cumulative") && imgCumulative != null) {
					imgref = imgCumulative;
				} else {
					imgref = ImageIO.read(new File(fileRef[0]));
					if (image.getWidth() != imgref.getWidth() || image.getHeight() != imgref.getHeight() || pixelSize != imgref.getColorModel().getPixelSize()) {
						throw new Exception("Image and Image Ref should be of same dimensions and pixelSize ! ("+sprite.name+")");
					}		
				}
				
				// Palette start and stop indexes
				String[] params = sprite.associatedIdx.split("\\(")[1].split("\\)")[0].split(":");
				int idx_min = Integer.parseInt(params[0]);
				int idx_max = Integer.parseInt(params[1]);
				if (idx_max-idx_min != 3) {
					throw new Exception ("_autopal wrong parameter, please provide two color index values, a start and end pos of 4 values length. Ex: 2:5 means use palette colors 2,3,4,5");
				}
				
	        	logger.debug("Process: "+sprite.spriteFile);
				
				// color index mapping table
				int[] cur_idx = new int[4]; // current palette combination
				int[] try_idx = new int[4]; // palette combination to try
				int[] bst_idx = new int[4]; // best palette combination

				// get last frame color palette
				byte cur_pal;
				if (associatedIdx == null || !fileRef[0].equals("_cumulative")) {
					cur_pal = (byte)0b00011011; // palette index are in original order : 0=0, 1=1, ...
				} else {
					// palette was remapped, get the mapping
					cur_pal = (byte)(((Character.digit(associatedIdx.charAt(1), 16) << 4) + Character.digit(associatedIdx.charAt(2), 16)) & 0xFF);
				}
				
				// each color index is encoded in 2 bits so this value means 4 color indexes : 0 (00), 1 (01) ,2 (10), 3 (11)
				cur_idx[0] = (cur_pal & 0b11000000) >> 6;
				cur_idx[1] = (cur_pal & 0b00110000) >> 4;
				cur_idx[2] = (cur_pal & 0b00001100) >> 2;
				cur_idx[3] = (cur_pal & 0b00000011);
				
				// init best count with actual palette
				// ***********************************
				// if the actual palette is found to be the best solution
				// it will be prefered to other equal solutions to save a palette switch at runtime
				
				int best_count = 0;
				boolean skip = false;
				outerloop:
		        for (int x = 0; x < image.getWidth(); x++) {
		            for (int y = 0; y < image.getHeight(); y++) {
		            	int val = (image.getRaster().getDataBuffer()).getElem(x+(y*image.getWidth()));
		            	int src = (imgref.getRaster().getDataBuffer()).getElem(x+(y*imgref.getWidth()));
		            	
		            	// check if previous pal matches new image palette usage, if not break
//		            	if (val >= idx_min && val <= idx_max && val-idx_min != cur_idx[0] && val-idx_min != cur_idx[1] && val-idx_min != cur_idx[2] && val-idx_min != cur_idx[3]) {
//		            		skip = true;
//		            		break outerloop;
//		            	}			            	
		            	
		            	if ((interlaced&&(y % 2 != 0)) ||
		            	    (src >= idx_min && src <= idx_max && val >= idx_min && val <= idx_max && cur_idx[val-idx_min] == src-idx_min) ||
		            	    ((src < idx_min || src > idx_max || val < idx_min || val > idx_max) && src == val)		            	    
		            	   ) {
		            		best_count++;
		            	}
		            }
		        }
				if (!skip) {
		        	bst_idx[0] = cur_idx[0]; 
		        	bst_idx[1] = cur_idx[1];
		        	bst_idx[2] = cur_idx[2];
		        	bst_idx[3] = cur_idx[3];
		        	logger.debug("\tPal cycle init, cleared pixels: "+best_count+" pal: "+bst_idx[0]+" "+bst_idx[1]+" "+bst_idx[2]+" "+bst_idx[3]);		        	
				} else {
					best_count = 0;
					logger.debug("\tPal cycle init, no initial solution found.");
				}
	        	
				// run all palette combinations
				// ****************************
				
	        	int[][] permut = new int[][]{{0,1,2,3},{1,0,2,3},{2,0,1,3},{0,2,1,3},{1,2,0,3},{2,1,0,3},{2,1,3,0},{1,2,3,0},{3,2,1,0},{2,3,1,0},{1,3,2,0},{3,1,2,0},{3,0,2,1},{0,3,2,1},{2,3,0,1},{3,2,0,1},{0,2,3,1},{2,0,3,1},{1,0,3,2},{0,1,3,2},{3,1,0,2},{1,3,0,2},{0,3,1,2},{3,0,1,2}};
				for (int i = 0; i < permut.length; i++) {
					int px_count = 0;
					skip = false;
					try_idx[0] = permut[i][0];
					try_idx[1] = permut[i][1];
					try_idx[2] = permut[i][2];
					try_idx[3] = permut[i][3];
					
					outerloop:
					// count cleared (identical) pixels
			        for (int x = 0; x < image.getWidth(); x++) {
			            for (int y = 0; y < image.getHeight(); y++) {
			            	int val = (image.getRaster().getDataBuffer()).getElem(x+(y*image.getWidth()));
			            	int src = (imgref.getRaster().getDataBuffer()).getElem(x+(y*imgref.getWidth()));	
			            	
			            	// check if previous pal matches new image palette usage, if not break
//			            	if (val >= idx_min && val <= idx_max && val-idx_min != try_idx[0] && val-idx_min != try_idx[1] && val-idx_min != try_idx[2] && val-idx_min != try_idx[3]) {
//			            		skip = true;
//			            		break outerloop;
//			            	}			            	
			            	
			            	if ((interlaced&&(y % 2 != 0)) ||
			            			(src >= idx_min && src <= idx_max && val >= idx_min && val <= idx_max && try_idx[val-idx_min] == src-idx_min) ||
				            	    ((src < idx_min || src > idx_max || val < idx_min || val > idx_max) && src == val)			            	    
				            	) {
			            		px_count++;
			            	}
			            }
			        }
			        
			        if (!skip && px_count > best_count) {
			        	best_count = px_count;
			        	bst_idx[0] = try_idx[0]; 
			        	bst_idx[1] = try_idx[1];
			        	bst_idx[2] = try_idx[2];
			        	bst_idx[3] = try_idx[3];
			        }
				}
				
				// clear similar pixels
		        for (int x = 0; x < image.getWidth(); x++) {
		            for (int y = 0; y < image.getHeight(); y++) {
		            	int val = (image.getRaster().getDataBuffer()).getElem(x+(y*image.getWidth()));
		            	int src = (imgref.getRaster().getDataBuffer()).getElem(x+(y*imgref.getWidth()));			            	
		            	if ((interlaced&&(y % 2 != 0)) ||
		            			(src >= idx_min && src <= idx_max && val >= idx_min && val <= idx_max && bst_idx[val-idx_min] == src-idx_min) ||
			            	    ((src < idx_min || src > idx_max || val < idx_min || val > idx_max) && src == val)			            	    
			            	) {
		            		((DataBufferByte) image.getRaster().getDataBuffer()).setElem(x+(y*image.getWidth()), colorModel.getRGB(0));
		            		image.setRGB(x, y, colorModel.getRGB(0));
		            	}
		            }
		        }					
						    
		        // rebuild palette index
		        byte[] coloridx = new byte[4];
		        coloridx[bst_idx[0]] = 0;
		        coloridx[bst_idx[1]] = 1;
		        coloridx[bst_idx[2]] = 2;
		        coloridx[bst_idx[3]] = 3;
		        
                // reassign color indexes of delta image with best palette
		    	byte[][] paletteRGBA = new byte[4][256];
		    	int paletteSize = 1; 

		    	for (int i = 1; i <= 16; i++) {
		    		if (i < idx_min || i > idx_max) {
		    			paletteRGBA[0][paletteSize] = (byte) (colorModel.getRed(i));
		    			paletteRGBA[1][paletteSize] = (byte) (colorModel.getGreen(i));
		    			paletteRGBA[2][paletteSize] = (byte) (colorModel.getBlue(i));
		    			paletteRGBA[3][paletteSize] = (byte) (colorModel.getAlpha(i));
		    		} else {
		    			paletteRGBA[0][paletteSize] = (byte) (colorModel.getRed(coloridx[i-idx_min]+idx_min));
	    				paletteRGBA[1][paletteSize] = (byte) (colorModel.getGreen(coloridx[i-idx_min]+idx_min));
	    				paletteRGBA[2][paletteSize] = (byte) (colorModel.getBlue(coloridx[i-idx_min]+idx_min));
	    				paletteRGBA[3][paletteSize] = (byte) (colorModel.getAlpha(i));
		    		}
		    		paletteSize++;
		    	}

		    	IndexColorModel newColorModel = new IndexColorModel(8,paletteSize+1,paletteRGBA[0],paletteRGBA[1],paletteRGBA[2],0);
		    	BufferedImage indexedImage = new BufferedImage(image.getWidth(), image.getHeight(), BufferedImage.TYPE_BYTE_INDEXED, newColorModel);

		    	for (int x = 0; x < indexedImage.getWidth(); x++) {
		    		for (int y = 0; y < indexedImage.getHeight(); y++) {
		    			int val = (image.getRaster().getDataBuffer()).getElem(x+(y*image.getWidth()));
		    			if (val < idx_min || val > idx_max) {
		    				(indexedImage.getRaster().getDataBuffer()).setElem(x+(y*image.getWidth()), val);
		    				//indexedImage.setRGB(x, y, colorModel.getRGB(val));
		    			} else {
		    				(indexedImage.getRaster().getDataBuffer()).setElem(x+(y*image.getWidth()), bst_idx[val-idx_min]+idx_min);
		    				//indexedImage.setRGB(x, y, colorModel.getRGB(bst_idx[val-idx_min]+idx_min));
		    			}
		    		}
		    	}
		        
		    	image = indexedImage;				
				
		        File outputfile = new File(generatedCodeDirNameDebug+Paths.get(sprite.spriteFile).getFileName().toString()+"_"+FileUtil.removeExtension(Paths.get(fileRef[0]).getFileName().toString())+"_diff.png");
		        ImageIO.write(image, "png", outputfile);
		        
                // merge images to get the new reference
		    	paletteSize = 1; 

		    	for (int i = 1; i <= 16; i++) {
		    		if (i < idx_min || i > idx_max) {
		    			paletteRGBA[0][paletteSize] = (byte) (colorModel.getRed(i));
		    			paletteRGBA[1][paletteSize] = (byte) (colorModel.getGreen(i));
		    			paletteRGBA[2][paletteSize] = (byte) (colorModel.getBlue(i));
		    			paletteRGBA[3][paletteSize] = (byte) (colorModel.getAlpha(i));
		    		} else {
		    			paletteRGBA[0][paletteSize] = (byte) (colorModel.getRed(coloridx[i-idx_min]+idx_min));
	    				paletteRGBA[1][paletteSize] = (byte) (colorModel.getGreen(coloridx[i-idx_min]+idx_min));
	    				paletteRGBA[2][paletteSize] = (byte) (colorModel.getBlue(coloridx[i-idx_min]+idx_min));
	    				paletteRGBA[3][paletteSize] = (byte) (colorModel.getAlpha(i));
		    		}
		    		paletteSize++;
		    	}

		    	IndexColorModel mergedColors = new IndexColorModel(8,paletteSize+1,paletteRGBA[0],paletteRGBA[1],paletteRGBA[2],0);
		    	BufferedImage mergedImage = new BufferedImage(imgref.getWidth(), imgref.getHeight(), BufferedImage.TYPE_BYTE_INDEXED, mergedColors);

		    	for (int x = 0; x < indexedImage.getWidth(); x++) {
		    		for (int y = 0; y < indexedImage.getHeight(); y++) {
		    			int val = (imgref.getRaster().getDataBuffer()).getElem(x+(y*imgref.getWidth()));
	    				(mergedImage.getRaster().getDataBuffer()).setElem(x+(y*imgref.getWidth()), val); 
	    				//mergedImage.setRGB(x, y, colorModel.getRGB(val));
		    		}
		    	}		    	
		    	
		    	for (int x = 0; x < indexedImage.getWidth(); x++) {
		    		for (int y = 0; y < indexedImage.getHeight(); y++) {
		    			int val = (image.getRaster().getDataBuffer()).getElem(x+(y*image.getWidth()));
		    			if (val != 0) {
		    				(mergedImage.getRaster().getDataBuffer()).setElem(x+(y*image.getWidth()), val);
		    				//mergedImage.setRGB(x, y, colorModel.getRGB(val));
		    			}
		    		}
		    	}
		    	
		        File outputfile2 = new File(generatedCodeDirNameDebug+Paths.get(sprite.spriteFile).getFileName().toString()+"_"+FileUtil.removeExtension(Paths.get(fileRef[0]).getFileName().toString())+".png");
		        ImageIO.write(mergedImage, "png", outputfile2);
		        		        
		        sprite.associatedIdx = new String(String.format("$%02X", coloridx[0] << 6 | coloridx[1] << 4 | coloridx[2] << 2 | coloridx[3]));
		        sprite.imgCumulative = mergedImage;
		        logger.debug("\tafter optim   , cleared pixels: "+best_count+" pal: "+coloridx[0]+" "+coloridx[1]+" "+coloridx[2]+" "+coloridx[3]);
	
			} else {
				if (fileRef.length > 0 && fileRef[0] != null) {
					BufferedImage imageRef = ImageIO.read(new File(fileRef[0]));
					if (image.getWidth() != imageRef.getWidth() || image.getHeight() != imageRef.getHeight() || pixelSize != imageRef.getColorModel().getPixelSize()) {
						throw new Exception("Image and Image Ref should be of same dimensions and pixelSize ! ("+sprite.name+")");
					}
					
					// Efface le pixel de l'image si celui-ci est identique à l'image de référence
			        for (int x = 0; x < image.getWidth(); x++) {
			            for (int y = 0; y < image.getHeight(); y++) {
			            	if ((interlaced&&(y % 2 != 0)) || (((image.getRaster().getDataBuffer()).getElem(x+(y*image.getWidth()))) ==
			            			                           ((imageRef.getRaster().getDataBuffer()).getElem(x+(y*imageRef.getWidth()))))
			            			                             ) {
			            		((DataBufferByte) image.getRaster().getDataBuffer()).setElem(x+(y*image.getWidth()), colorModel.getRGB(0));
			            		image.setRGB(x, y, colorModel.getRGB(0));
			            	}
			            }
			        }
			        
			        File outputfile = new File(generatedCodeDirNameDebug+Paths.get(sprite.spriteFile).getFileName().toString()+"_"+FileUtil.removeExtension(Paths.get(fileRef[0]).getFileName().toString())+"_diff.png");
			        ImageIO.write(image, "png", outputfile);
				}
			}

			if (width % nbColumns == 0 && height % nbRows == 0) { // Est-ce que la division de la largeur par le nombre d'images donne un entier ?

				subImageWidth = width/nbColumns; // Largeur de la sous-image
				subImageHeight = height/nbRows; // Hauteur de la sous-image

				//if (subImageWidth <= 160 && height <= 200 && pixelSize == 8) { // Contrôle du format d'image
				if (pixelSize == 8) { // Contrôle du format d'image

					// On inverse l'image horizontalement et verticalement		
					if (variant.contains("XY")) {
						hFlipped = true;
						vFlipped = true;
						AffineTransform tx = AffineTransform.getScaleInstance(-1, -1);
						tx.translate(-image.getWidth(null), -image.getHeight(null));
						AffineTransformOp op = new AffineTransformOp(tx, AffineTransformOp.TYPE_NEAREST_NEIGHBOR);
						image = op.filter(image, null);
					}					
					
					// On inverse l'image horizontalement (x mirror)
					else if (variant.contains("X")) {
						hFlipped = true;
						AffineTransform tx = AffineTransform.getScaleInstance(-1, 1);
						tx.translate(-image.getWidth(null), 0);
						AffineTransformOp op = new AffineTransformOp(tx, AffineTransformOp.TYPE_NEAREST_NEIGHBOR);
						image = op.filter(image, null);
					}

					// On inverse l'image verticalement (y mirror)		
					else if (variant.contains("Y")) {
						vFlipped = true;
						AffineTransform tx = AffineTransform.getScaleInstance(1, -1);
						tx.translate(0, -image.getHeight(null));
						AffineTransformOp op = new AffineTransformOp(tx, AffineTransformOp.TYPE_NEAREST_NEIGHBOR);
						image = op.filter(image, null);
					}

				} else {
					logger.info("Le format de fichier de " + sprite.spriteFile + " n'est pas supporté.");
					logger.info("Resolution: " + subImageWidth + "x" + height + "px (doit être inférieur ou égal à 160x200)");
					logger.info("Taille pixel:  " + pixelSize + "Bytes (doit être 8)");
					throw new Exception ("Erreur de format d'image PNG.");
				}
			}
			else if (width % nbColumns != 0) {
				logger.info("La largeur d'image :" + width + " n'est pas divisible par le nombre de colonnes de tiles :" +  nbColumns);
				throw new Exception ("Erreur de format d'image PNG.");
			}
			else if (height % nbRows != 0) {
				logger.info("La hauteur d'image :" + height + " n'est pas divisible par le nombre de lignes de tiles :" +  nbRows);
				throw new Exception ("Erreur de format d'image PNG.");
			}

		} catch (Exception e) {
			e.printStackTrace();
			System.out.println(e);
		}
	}
	


}